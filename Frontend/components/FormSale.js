import { buyDataset } from "../utils/app";
import toast from "react-hot-toast";

// export default function FormSalePreview({ item }) {
    export default function FormSalePreview() {

    return (
        <div class="w-full">
                        <div class="relative w-full px-4 py-6 bg-white shadow-lg dark:bg-gray-700">
                            <p class="text-sm font-bold text-lg text-gray-700 border-b border-gray-200 w-max dark:text-white">
                                Protocol Survey
                            </p>
                            <div class="flex items-end my-6 space-x-2">
                                <p class="text text-black dark:text-white">
                                    {/* {item[2]} */} survey of DeFi protocol usage
                                </p>
                            </div>
                            <div class="dark:text-white">
                                <div class="flex items-center justify-between pb-2 mb-2 text-sm border-b border-gray-200 sm:space-x-12">
                                    <p>
                                        Category
                                    </p>
                                    <div class="flex items-end text-xs">
                                        Protocol Survey
                                    </div>
                                </div>
                                <div class="flex items-center justify-between pb-2 mb-2 space-x-12 text-sm border-b border-gray-200 md:space-x-24">
                                    <p>
                                        Fields
                                    </p>
                                    <div class="flex items-end text-xs">
                                        3
                                    </div>
                                </div>
                                <div class="flex items-center justify-between space-x-12 text-sm md:space-x-24">
                                    <p>
                                        Responses
                                    </p>
                                    <div class="flex items-end text-xs">
                                        {/* {item[5]} */} 1
                                    </div>
                                </div>
                                <div class="flex items-center justify-between space-x-12 text-sm md:space-x-24">
                                    <p>
                                        Price
                                    </p>
                                    <div class="flex items-end text-xs">
                                        {Number(item[3])} MATIC
                                    </div>
                                </div>
                                <div class="flex items-center">
                                <button
                                    onClick={async () => {
                                        await buyDataset(item[0]);
                                        toast.success("You purched the form");
                                    }}
                                    className="relative inline-block px-4 py-2 font-medium group "
                                    >
                                    <span className="absolute rounded-lg inset-0 w-full h-full transition duration-200 ease-out transform translate-x-1 translate-y-1 bg-[#0070f3] border-[2px] border-black group-hover:-translate-x-0 group-hover:-translate-y-0"></span>
                                    <span className="absolute rounded-lg inset-0 w-full h-full bg-white border-2 border-black group-hover:bg-[#0070f3]"></span>
                                    <span className="relative text-black">Buy</span>
                                    </button>
                                </div>
                            </div>
                        </div>
        </div>
    );
  }