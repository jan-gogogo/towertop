/**
 * Deployed contract addresses (from script/DeployGame.s.sol).
 * Deployment was to Ronin Saigon Testnet; chainId from RPC was 202601.
 */
export const CONTRACTS = {
  /** Chain id used when deploying (Ronin Saigon RPC returned this). */
  chainId: 202601,
  chainIdHex: "0x31769",

  /** RPC URL for Ronin Saigon Testnet (e.g. for eth_getTransactionReceipt). */
  rpcUrl: "https://saigon-testnet.roninchain.com/rpc",

  /** Main entry: IGameLogic - all game actions go through this proxy. */
  gameProxy: "0xea8cf0099674B6c8DF6EefB767b0cA3C0227BF81",

  heroProxy: "0x0841105ecbcb7B58682AF70d3CDDCf87010ad423",
  inventoryProxy: "0x4422Ef25B46d897722D588F64a0978922fb56235",

  /** ERC20 game token; used for approve + deposit/withdraw. */
  token: "0xE9c53Da34e0FE05817fc2506402b18c79B2a5250",

  /** Game assets (equipment NFTs, etc.). */
  assets: "0x6d798A5D4B01a3bB4E73C07F62e2A041CdF5004F",
};
