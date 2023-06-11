import mainnet_config from "./constants/mainnet-config";
import testnet_config from "./constants/testnet-config";

async function main(){
    const [
        Magma,
        MerkleClaim
    ] = await Promise.all([
        hre.ethers.getContractFactory("Magma"),
        hre.ethers.getContractFactory("MerkleClaim")
    ]);
    const network = await hre.ethers.provider.getNetwork();
    const chainId = network.chainId;
    const mainnet = chainId === 2222;
    console.log(`#Network: ${chainId}`);
    const CONFIG = mainnet ? mainnet_config : testnet_config;
    const magma = await Magma.deploy();
    await magma.deployed();
    const claim = await MerkleClaim.deploy(magma.address, CONFIG.merkleRoot);
    await claim.deployed();
    console.log('magma', magma.address);
    console.log('merkle', claim.address);
    await magma.setMerkleClaim(claim.address);
    await hre.run("verify:verify", {address: claim.address,
        constructorArguments: [magma.address, CONFIG.merkleRoot]});
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

