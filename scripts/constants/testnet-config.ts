import {ethers} from "ethers";
const TEAM_MULTISIG = "0x83B35466ff8ec3b714c17697930ec304f7FF0057";
const TEAM_EOA = "0x83B35466ff8ec3b714c17697930ec304f7FF0057";
const WETH = "0x6C2A54580666D69CF904a82D8180F198C03ece67";
const USDC = "0x43D8814FdFB9B8854422Df13F1c66e34E4fa91fD";
const testnetArgs = {
    WETH: WETH,
    USDC: USDC,
    teamEOA: TEAM_EOA,
    teamTreasure: '0x83B35466ff8ec3b714c17697930ec304f7FF0057',
    teamMultisig: TEAM_MULTISIG,
    emergencyCouncil: TEAM_EOA,
    merkleRoot: "0x6362f8fcdd558ac55b3570b67fdb1d1673bd01bd53302e42f01377f102ac80a9",
    tokenWhitelist: [],
    partnerAddrs: [

    ],
    partnerAmts: [

    ],
};

export default testnetArgs;
