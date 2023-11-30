// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@tableland/evm/contracts/utils/TablelandDeployments.sol";
import "@tableland/evm/contracts/utils/SQLHelpers.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";


interface RouterContract {
    function addTable(address formOwner, string memory tablePrefix, address tableContract, uint256 tableId) external;
}

interface MarketPlace {
    function listDataset(uint256 price, uint256 tablelandId, address lister, address listerContract, uint256 responseCount, string memory tableName, string memory tableDescription) external;
    function delistDataset(uint256 id) external;
}

contract userTables is ERC721Holder, ERC1155, FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    using Counters for Counters.Counter; // OpenZepplin Counter
    Counters.Counter private _tableCount; // Counter For tables
    
    // State variables to store the last request ID, response, and error
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    // Event to log responses
    event Response(
        bytes32 indexed requestId,
        string character,
        bytes response,
        bytes err
    );

    // Router address - Hardcoded for Mumbai
    address router = 0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C;

    string source =
    "const characterId = args[0];"
    "const apiResponse = await Functions.makeHttpRequest({"
    "url: `https://swapi.dev/api/people/${characterId}/`"
    "});"
    "if (apiResponse.error) {"
    "throw Error('Request failed');"
    "}"
    "const { data } = apiResponse;"
    "return Functions.encodeString(data.name);";

    //Callback gas limit
    uint32 gasLimit = 300000;

    // donID - Hardcoded for Mumbai
    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID =
        0x66756e2d706f6c79676f6e2d6d756d6261692d31000000000000000000000000;

    // State variable to store the returned character information
    string public character;

    address public owner;
    address public controllerContract;
    address public marketAddress;

    IERC721 Tableland;
    RouterContract routerContract;
    MarketPlace marketPlace;

    // table struct
    struct Table {
        uint256 tableId;
        uint256 tablelandId;
        string tablePrefix;
        string tableName;
        string description;
        uint256 responseCount;
    }

    // struct of reward
    struct Reward {
        uint256 totalAmount;
        uint256 singleAmount;
        address tokenAddress;
    }

    // mapping table counters to tables
    mapping (uint256 => Table) Tables;

    // mapping of a table id to the reward for the table
    mapping (uint256 => Reward) tableReward;

    // mapping of ids to writeString
    mapping (uint256 => string) writeQueries;

    // mapping to check if a filling a table is rewarded with an NFT
    mapping (uint256 => bool) mintable;

    constructor(address _routerContract, address _controllerContract, address registryAddress, address _marketPlace) ERC1155("hash") FunctionsClient(router) ConfirmedOwner(msg.sender) {
        owner = msg.sender;
        routerContract = RouterContract(_routerContract);
        controllerContract = _controllerContract;
        Tableland = IERC721(registryAddress);
        marketPlace = MarketPlace(_marketPlace);
        marketAddress = _marketPlace;
    }

    /**
     * @notice Sends an HTTP request for character information
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequest(
        uint64 subscriptionId,
        string[] calldata args
    ) external onlyOwner returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return s_lastRequestId;
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId); // Check if request IDs match
        }
        // Update the contract's state variables with the response and any errors
        s_lastResponse = response;
        character = string(response);
        s_lastError = err;

        // Emit an event to log the response
        emit Response(requestId, character, s_lastResponse, s_lastError);
    }

    // function to create a table
    // try creating the table first then
    // setting the access controller to the contract
    function createTable(string memory tablePrefix, string memory createString, string memory description, string memory writeQuery) public onlyOwner {

        uint256 id = TablelandDeployments.get().create( // creating a table ID
            address(this), // setting it's owner to the address for easy write access
            SQLHelpers.toCreateFromSchema(
                string.concat("id integer primary key,", createString),
                tablePrefix // the needed prefix for table
            )
        );

        string memory tableName = string.concat(
            tablePrefix, "_", Strings.toString(block.chainid), "_", Strings.toString(id)
        );

        Tables[_tableCount.current()].description = description;
        Tables[_tableCount.current()].tablePrefix = tablePrefix;
        Tables[_tableCount.current()].tableId = _tableCount.current();
        Tables[_tableCount.current()].tablelandId = id;
        Tables[_tableCount.current()].tableName = tableName;
        
        TablelandDeployments.get().setController(address(this), id, controllerContract);
        
        writeQueries[_tableCount.current()] = writeQuery;
        
        routerContract.addTable(msg.sender, tablePrefix, address(this), _tableCount.current());
        _tableCount.increment();
    }

    // implement access control
    function getTableName(uint256 id) public view returns(string memory tableName) {
        tableName = Tables[id].tableName;
    }

    function getColumns(uint256 id) public view returns(string memory columns) {
        columns = writeQueries[id];
    }

    // function to write to a table
    // implements tableland access control function for fees
    function writeTable(uint256 id, string[] memory responses) public payable {
          string memory response = concatWriteArray(responses);
          string memory writeQuery = writeQueries[id];
        //   check for native rewards
          if (address(this).balance > tableReward[id].singleAmount && tableReward[id].totalAmount > 0) {
          TablelandDeployments.get().mutate{value:msg.value}(
            address(this),
            Tables[id].tablelandId,
            SQLHelpers.toInsert(
            Tables[id].tablePrefix,
            Tables[id].tablelandId,
            string.concat("id,", writeQuery),
            string.concat(
            Strings.toString(Tables[id].responseCount), // Convert to a string
            ",",
            response
            )
            )
        );

        (bool sent, bytes memory data) = payable(msg.sender).call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        Tables[id].responseCount += 1;
          } else {
            TablelandDeployments.get().mutate{value:msg.value}(
            address(this),
            Tables[id].tablelandId,
            SQLHelpers.toInsert(
            Tables[id].tablePrefix,
            Tables[id].tablelandId,
            string.concat("id,", writeQuery),
            string.concat(
            Strings.toString(Tables[id].responseCount), // Convert to a string
            ",",
            response
            )
            )
        );
        Tables[id].responseCount += 1;
        }

    }

    function getCount() public view returns(uint256) {
        return _tableCount.current();
    }

    function getTable(uint256 id) public view returns(uint256, string memory, string memory, string memory, uint256) {
        return(Tables[id].tableId, Tables[id].tablePrefix, Tables[id].description, writeQueries[id], Tables[id].responseCount);
    }

    // function to list Table
    function listTable(uint256 id, uint256 price) public onlyOwner {
        marketPlace.listDataset(price, Tables[id].tablelandId, msg.sender, address(this), Tables[id].responseCount, Tables[id].tablePrefix, Tables[id].description);
        Tableland.approve(marketAddress, Tables[id].tablelandId);
    }

    function concatWriteArray(string[] memory fields) internal pure returns (string memory) {
        string memory queryString;
        for (uint i = 0; i < fields.length; i++) {
            if(i == (fields.length - 1)) {
            queryString = string.concat(
                queryString,
                SQLHelpers.quote(fields[i])
            );
            }
            else {
            queryString = string.concat(
                queryString,
                SQLHelpers.quote(fields[i]), ","
            );
            }
        }
        return queryString;
    }

    // function to uppdate controller
    function updateController(uint256 id, address controller) public onlyOwner {
        TablelandDeployments.get().setController(address(this), Tables[id].tablelandId, controller);
    }

    // function to add a reward for filling a form
    function addRewardNative(uint256 id, uint256 singleAmount) public payable onlyOwner {
        // map it to the tableId
        tableReward[id].totalAmount = msg.value;
        // define what each response should get
        tableReward[id].singleAmount = singleAmount;
    }

    // implement addFee function
    // prolly do that with tableland access control

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
}

