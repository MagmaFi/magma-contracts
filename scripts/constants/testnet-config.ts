import {ethers} from "ethers";
const TEAM_MULTISIG = "0x1790E1b8D76f8f7c5603FB304Bf4CCE7a2065A89";
const TEAM_EOA = "0x1790E1b8D76f8f7c5603FB304Bf4CCE7a2065A89";
const WETH = "0xc0A7F1B0c9988FbC123f688a521387A51596da47";
const testnetArgs = {
    WETH: WETH,
    teamEOA: TEAM_EOA,
    teamTreasure: '0x1790E1b8D76f8f7c5603FB304Bf4CCE7a2065A89',
    teamMultisig: TEAM_MULTISIG,
    emergencyCouncil: TEAM_EOA,
    merkleRoot: "0x6362f8fcdd558ac55b3570b67fdb1d1673bd01bd53302e42f01377f102ac80a9",
    tokenWhitelist: [],
    partnerAddrs: [
        '0xb60D2E146903852A94271B9A71CF45aa94277eB5',
        '0x83c96857773898214A0f6e31a791001FFAb42D9f'
    ],
    partnerAmts: [
        "1000000",
        "1000000",
    ],
};

export default testnetArgs;
