import { ethers } from "ethers";
function toWei(n: string | number) {
  return ethers.utils.parseEther(n.toString());
}
const mainnet_config = {
  WETH: "0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b",
  USDC: "0xfA9343C3897324496A05fC75abeD6bAC29f8A40f",
  USDC_DECIMALS: 6,
  wKAVA_USDC: "0x5c27a0d0e6d045b5113d728081268642060f7499",
  oToken_USDC: "0x9bf1E3ee61cBe5C61E520c8BEFf45Ed4D8212a9A",
  oToken_KAVA: "0x7d8100072ba0e4da8dc6bd258859a5dc1a452e05",
  POOL2: "0xCa0d15B4BB6ad730fE40592f9E25A2E052842c92",
  teamEOA: "0x83B35466ff8ec3b714c17697930ec304f7FF0057",
  teamTreasure: '0x83B35466ff8ec3b714c17697930ec304f7FF0057',
  teamMultisig: "0x83B35466ff8ec3b714c17697930ec304f7FF0057",
  emergencyCouncil: "0x83B35466ff8ec3b714c17697930ec304f7FF0057",
  merkleRoot: "0x6362f8fcdd558ac55b3570b67fdb1d1673bd01bd53302e42f01377f102ac80a9",
  tokenWhitelist: [],
  partnerAddrs: [

  ],
  partnerAmts: [

  ],
  teamAmount: toWei(100_000_000),
};

const testnetArgs = {
  WETH: "0x6C2A54580666D69CF904a82D8180F198C03ece67",
  USDC: "0x43D8814FdFB9B8854422Df13F1c66e34E4fa91fD",
  teamEOA: "0x83B35466ff8ec3b714c17697930ec304f7FF0057",
  teamTreasure: '0x83B35466ff8ec3b714c17697930ec304f7FF0057',
  teamMultisig: "0x83B35466ff8ec3b714c17697930ec304f7FF0057",
  emergencyCouncil: "0x83B35466ff8ec3b714c17697930ec304f7FF0057",
  merkleRoot: "0x6362f8fcdd558ac55b3570b67fdb1d1673bd01bd53302e42f01377f102ac80a9",
  tokenWhitelist: [],
  partnerAddrs: [

  ],
  partnerAmts: [

  ],
  teamAmount: toWei(100_000_000),
};

export default function getDeploymentConfig(isMainnet:boolean): any {
    return isMainnet ? mainnet_config : testnetArgs
}
