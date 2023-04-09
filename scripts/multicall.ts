import {task} from "hardhat/config";

async function main() {
    const network = await hre.ethers.provider.getNetwork();
    const chainId = network.chainId;
    const mainnet = chainId === 5000;
    console.log(`#Network: ${chainId}`);

    /*
    const Multicall = await hre.ethers.getContractFactory("Multicall");
    const multicall = await Multicall.deploy();
    await multicall.deployed();
    try {
        if (chainId === 5000 || chainId === 5001) {
            await multicall.deployTransaction.wait(5);
            await hre.run("verify:verify",
                {
                    contract: "contracts/Multicall.sol:Multicall",
                    address: multicall.address
                }
            );
        }
    } catch (e) {
        console.log(e.toString());
    }

    const Multicall2 = await hre.ethers.getContractFactory("Multicall2");
    const multicall2 = await Multicall2.deploy();
    await multicall2.deployed();
    try {
        if (chainId === 5000 || chainId === 5001) {
            await multicall2.deployTransaction.wait(5);
            await hre.run("verify:verify",
                {
                    contract: "contracts/Multicall2.sol:Multicall2",
                    address: multicall2.address
                }
            );
        }
    } catch (e) {
        console.log(e.toString());
    }
    */

    const Multicall3 = await hre.ethers.getContractFactory("Multicall3");
    const multicall3 = await Multicall3.deploy();
    await multicall3.deployed();
    try {
        if (chainId === 5000 || chainId === 5001) {
            await multicall3.deployTransaction.wait(5);
            await hre.run("verify:verify",
                {
                    contract: "contracts/Multicall3.sol:Multicall3",
                    address: multicall3.address
                }
            );
        }
    } catch (e) {
        console.log(e.toString());
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

