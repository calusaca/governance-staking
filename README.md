## Governance Token 

The **DelegatorFactory** is a contract that allows a governor to create a **Delegator** contract that allows it to receive governance token delegation from other users. If the **DelegatorFactory** contract is used, stakers / delegators will earn reward tokens the longer they have staked.

The **delegatorFactory** contract is based on Synthetix Liquidity Rewards contract.


### How to run

1. Clone the Repo
2. Install [dappTools](https://github.com/dapphub/dapptools#installation).
3. Install dependencies `yarn install`
4. Delete folders 
	- lib/openzeppelin-contracts
	- lib/openzeppelin-solidity
	- lib/ds-test
6. Execute "dapp install ds-test"
7. Execute "dapp install OpenZeppelin/zeppelin-solidity"
8. Execute "dapp install  OpenZeppelin/openzeppelin-contracts"

### How to test

Run 

```shell
yarn test
``` 

or

```shell
dapp test --verbosity 1
```

### Audits

This contract has been audited by Quanstamp, you can read the audit here: https://certificate.quantstamp.com/view/cryptex

### Discussions

If you want to discuss this repo you can join [Cryptex Discord](https://discord.gg/2uMwMKJRaq).
