export const FEE_DISTRIBUTOR_ABI = [
  {
    name: 'treasury',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'reserveBuffer',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'treasuryShareBps',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'reserveShareBps',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'setRevenueSplit',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: '_treasuryBps', type: 'uint256' },
      { name: '_reserveBps', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    name: 'releaseTreasury',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    name: 'releaseReserve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
] as const;
