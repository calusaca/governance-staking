// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../../lib/ds-test/src/test.sol";
import "./hevm.sol";

import "../Delegator.sol";
import "../DelegatorFactory.sol";
import "../mocks/GovernanceToken.sol";

contract User {
   function approveAmount(
      GovernanceToken t,
      DelegatorFactory d,
      uint256 a
   ) public {
      t.approve(address(d), a);
   }

   function doCreateDelegator(DelegatorFactory d, address delegatee) public {
      d.createDelegator(delegatee);
   }

   function doDelegate(
      DelegatorFactory d,
      address delegator,
      uint256 amount
   ) public {
      d.stake(delegator, amount);
   }

   function doRemoveDelegate(
      DelegatorFactory d,
      address delegator,
      uint256 amount
   ) public {
      d.withdraw(delegator, amount);
   }

   function doUpdateWaitTime(DelegatorFactory d, uint256 waitTime) public {
      d.updateWaitTime(waitTime);
   }

   function doUpdateRewards(DelegatorFactory d, uint256 reward) public {
      d.notifyRewardAmount(reward);
   }

   function doSetRewardsDuration(DelegatorFactory d, uint256 time) public {
      d.setRewardsDuration(time);
   }

   function doClaimRewards(DelegatorFactory d) public {
      d.getReward();
   }
}

contract FakeDelegator {
   function stake(address staker_, uint256 amount_) public {
      // do nothing and keep funds
   }

   function removeStake(address staker_, uint256 amount_) public {
      // do nothing and keep funds
   }
}

contract FakeToken {
   function decimals() public pure returns (uint8) {
      return 10;
   }
}

contract DelegatorFactoryTest is DSTest {
   DelegatorFactory delegatorFactory;
   GovernanceToken ctx;
   User user1;
   uint256 waitTime = 1 weeks;
   Hevm public hevm = Hevm(HEVM_ADDRESS);

   function setUp() public {
      ctx = new GovernanceToken(address(this), address(this), block.timestamp);
      delegatorFactory = new DelegatorFactory(
         address(ctx),
         address(ctx),
         waitTime,
         address(this)
      );
      user1 = new User();
   }

   function test_parameters() public {
      assertEq(delegatorFactory.owner(), address(this));
      assertEq(delegatorFactory.stakingToken(), address(ctx));
      assertEq(delegatorFactory.waitTime(), waitTime);
      assertEq(delegatorFactory.rewardsToken(), address(ctx));
      assertEq(delegatorFactory.rewardsDuration(), 186 days);
   }

   function testFail_invalidStakingToken() public {
      new DelegatorFactory(address(0x0), address(ctx), waitTime, address(this));
   }

   function testFail_invalidRewardToken() public {
      new DelegatorFactory(address(ctx), address(0x0), waitTime, address(this));
   }

   function testFail_invalidStakingTokenDecimals() public {
      FakeToken f = new FakeToken();
      new DelegatorFactory(address(f), address(ctx), waitTime, address(this));
   }

   function testFail_invalidRewardTokenDecimals() public {
      FakeToken f = new FakeToken();
      new DelegatorFactory(address(ctx), address(f), waitTime, address(this));
   }

   function testFail_invalidTimelock() public {
      new DelegatorFactory(address(ctx), address(ctx), waitTime, address(0x0));
   }

   function test_createDelegator(address delegatee) public {
      if (delegatee == address(0)) return;
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);
      Delegator d = Delegator(delegator);
      assertEq(d.delegatee(), delegatee);
      assertEq(delegatorFactory.delegateeToDelegator(delegatee), address(d));
      assertEq(delegatorFactory.delegatorToDelegatee(address(d)), delegatee);
      assertEq(d.owner(), address(delegatorFactory));
   }

   function testFail_invalidCreateDelegator() public {
      delegatorFactory.createDelegator(address(0));
   }

   function testFail_createDelegator(address delegatee) public {
      delegatorFactory.createDelegator(delegatee);
      delegatorFactory.createDelegator(delegatee);
   }

   function test_delegate() public {
      address delegatee = address(0x1);
      uint256 amount = 1 ether;
      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      uint256 prevBalDelegator = ctx.balanceOf(delegator);
      uint256 prevBalStaker = ctx.balanceOf(address(this));
      uint256 prevBalDelegatee = ctx.balanceOf(delegatee);
      assertEq(prevBalDelegatee, 0);
      assertEq(prevBalDelegator, 0);

      // Delegate
      ctx.approve(address(delegatorFactory), amount);
      delegatorFactory.stake(delegator, amount);

      uint256 balDelegatee = ctx.balanceOf(delegatee);
      uint256 balDelegator = ctx.balanceOf(delegator);
      assertEq(ctx.balanceOf(address(this)), prevBalStaker - amount);
      assertEq(balDelegatee, 0);
      assertEq(balDelegator, amount);
      assertEq(ctx.getCurrentVotes(delegatee), amount);
      assertEq(
         delegatorFactory.stakerWaitTime(address(this), delegator),
         waitTime
      );
      assertEq(amount, delegatorFactory.balanceOf(address(this)));
      assertEq(amount, delegatorFactory.totalSupply());
   }

   function test_delegateFuzz(address delegatee, uint256 amount) public {
      if (amount > ctx.totalSupply()) return;
      if (amount == 0) return;
      if (delegatee == address(0)) return;

      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      uint256 prevBalDelegator = ctx.balanceOf(delegator);
      uint256 prevBalStaker = ctx.balanceOf(address(this));
      uint256 prevBalDelegatee = ctx.balanceOf(delegatee);
      assertEq(prevBalDelegatee, 0);
      assertEq(prevBalDelegator, 0);

      // Delegate
      ctx.approve(address(delegatorFactory), amount);
      delegatorFactory.stake(delegator, amount);

      uint256 balDelegatee = ctx.balanceOf(delegatee);
      uint256 balDelegator = ctx.balanceOf(delegator);
      assertEq(ctx.balanceOf(address(this)), prevBalStaker - amount);
      assertEq(balDelegatee, 0);
      assertEq(balDelegator, amount);
      assertEq(ctx.getCurrentVotes(delegatee), amount);
      assertEq(
         delegatorFactory.stakerWaitTime(address(this), delegator),
         waitTime
      );
      assertEq(amount, delegatorFactory.balanceOf(address(this)));
      assertEq(amount, delegatorFactory.totalSupply());
   }

   function testFail_invalidDelegator() public {
      uint256 amount = 1 ether;
      ctx.transfer(address(user1), amount);
      FakeDelegator faker = new FakeDelegator();
      user1.approveAmount(ctx, delegatorFactory, amount);
      user1.doDelegate(delegatorFactory, address(faker), amount);
   }

   function testFail_invalidAmount() public {
      address delegatee = address(0x1);
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);
      delegatorFactory.stake(delegator, 0);
   }

   function test_multipleDelegators(uint256 amount, uint256 amount2) public {
      if (amount > ctx.totalSupply() / 2 || amount2 > ctx.totalSupply() / 2)
         return;
      if (amount == 0 || amount2 == 0) return;
      uint256 prevBalStaker = ctx.balanceOf(address(this));
      address delegatee1 = address(0x1);
      address delegatee2 = address(0x2);
      delegatorFactory.createDelegator(delegatee1);
      delegatorFactory.createDelegator(delegatee2);
      address delegator1 = delegatorFactory.delegateeToDelegator(delegatee1);
      address delegator2 = delegatorFactory.delegateeToDelegator(delegatee2);
      ctx.approve(address(delegatorFactory), amount + amount2);
      delegatorFactory.stake(delegator1, amount);
      hevm.warp(waitTime);
      delegatorFactory.stake(delegator2, amount2);

      assertEq(
         ctx.balanceOf(address(this)),
         prevBalStaker - (amount + amount2)
      );
      assertEq(ctx.balanceOf(delegator1), amount);
      assertEq(ctx.balanceOf(delegator2), amount2);
      assertEq(ctx.getCurrentVotes(delegatee1), amount);
      assertEq(ctx.getCurrentVotes(delegatee2), amount2);
      assertEq(
         delegatorFactory.stakerWaitTime(address(this), delegator1),
         waitTime
      );
      assertEq(
         delegatorFactory.stakerWaitTime(address(this), delegator2),
         2 weeks
      );
      assertEq(amount + amount2, delegatorFactory.balanceOf(address(this)));
      assertEq(amount + amount2, delegatorFactory.totalSupply());
   }

   function test_unDelegate() public {
      address delegatee = address(0x1);
      uint256 amount = 1 ether;
      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      uint256 prevBalStaker = ctx.balanceOf(address(this));

      // Delegate
      ctx.approve(address(delegatorFactory), amount);
      delegatorFactory.stake(delegator, amount);

      // Time Skip
      hevm.warp(waitTime + 1 seconds);

      // Remove Delegate
      delegatorFactory.withdraw(delegator, amount);
      uint256 balDelegatee = ctx.balanceOf(delegatee);
      uint256 balDelegator = ctx.balanceOf(delegator);
      assertEq(ctx.balanceOf(address(this)), prevBalStaker);
      assertEq(balDelegatee, 0);
      assertEq(balDelegator, 0);
      assertEq(ctx.getCurrentVotes(delegatee), 0);
      assertEq(0, delegatorFactory.balanceOf(address(this)));
      assertEq(0, delegatorFactory.totalSupply());
   }

   function test_unDelegateFuzz(address delegatee, uint256 amount) public {
      if (amount > ctx.totalSupply()) return;
      if (amount == 0) return;
      if (delegatee == address(0)) return;

      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      uint256 prevBalStaker = ctx.balanceOf(address(this));

      // Delegate
      ctx.approve(address(delegatorFactory), amount);
      delegatorFactory.stake(delegator, amount);

      // Time Skip
      hevm.warp(waitTime + 1 seconds);

      // Remove Delegate
      delegatorFactory.withdraw(delegator, amount);
      uint256 balDelegatee = ctx.balanceOf(delegatee);
      uint256 balDelegator = ctx.balanceOf(delegator);
      assertEq(ctx.balanceOf(address(this)), prevBalStaker);
      assertEq(balDelegatee, 0);
      assertEq(balDelegator, 0);
      assertEq(ctx.getCurrentVotes(delegatee), 0);
      assertEq(0, delegatorFactory.balanceOf(address(this)));
      assertEq(0, delegatorFactory.totalSupply());
   }

   function test_unDelegateWithWait() public {
      address delegatee = address(0x1);
      uint256 amount = 1 ether;
      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      // Delegate
      ctx.approve(address(delegatorFactory), amount);
      delegatorFactory.stake(delegator, amount);

      //wait 1 week
      hevm.warp(waitTime + 1);

      // Delegate
      ctx.approve(address(delegatorFactory), amount);
      delegatorFactory.stake(delegator, amount);

      // Remove Delegate
      delegatorFactory.withdraw(delegator, (amount));
   }

   function testFail_unDelegateNoWait(address delegatee, uint256 amount)
      public
   {
      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      // Delegate
      ctx.approve(address(delegatorFactory), amount);
      delegatorFactory.stake(delegator, amount);

      // Remove Delegate
      delegatorFactory.withdraw(delegator, (amount));
   }

   function test_unDelegateWaitMultiple() public {
      address delegatee = address(0x1);
      uint256 amount = 1 ether;
      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      // Delegate
      ctx.approve(address(delegatorFactory), amount * 2);
      delegatorFactory.stake(delegator, amount);

      // Delegate
      hevm.warp(3 days);
      delegatorFactory.stake(delegator, amount);

      hevm.warp(waitTime + 1);
      // Remove Delegate
      delegatorFactory.withdraw(delegator, (amount));
   }

   function testFail_unDelegateWaitMultiple() public {
      address delegatee = address(0x1);
      uint256 amount = 1 ether;
      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      // Delegate
      ctx.approve(address(delegatorFactory), amount * 2);
      delegatorFactory.stake(delegator, amount);

      // Delegate
      hevm.warp(3 days);
      delegatorFactory.stake(delegator, amount);

      hevm.warp(waitTime + 1);
      // Remove Delegate
      delegatorFactory.withdraw(delegator, (amount * 2));
   }

   function testFail_unDelegateWaitMultipleCalls() public {
      address delegatee = address(0x1);
      uint256 amount = 1 ether;
      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      // Delegate
      ctx.approve(address(delegatorFactory), amount * 2);
      delegatorFactory.stake(delegator, amount);

      // Delegate
      hevm.warp(3 days);
      delegatorFactory.stake(delegator, amount);

      hevm.warp(waitTime + 1);
      // Remove Delegate
      delegatorFactory.withdraw(delegator, (amount));
      delegatorFactory.withdraw(delegator, (amount));
   }

   function testFail_unDelegateNoWaitMultiple() public {
      address delegatee = address(0x0);
      uint256 amount = 1 ether;
      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      // Delegate
      ctx.approve(address(delegatorFactory), amount * 2);
      delegatorFactory.stake(delegator, amount);

      // Delegate
      hevm.warp(3 days);
      delegatorFactory.stake(delegator, amount);

      // Remove Delegate
      delegatorFactory.withdraw(delegator, (amount));
   }

   function test_unDelegateSpecific(
      address delegatee,
      uint256 amount,
      uint256 amount2
   ) public {
      if (amount > ctx.totalSupply() / 2 || amount2 > ctx.totalSupply() / 2)
         return;
      if (amount == 0 || amount2 == 0) return;
      if (delegatee == address(0)) return;

      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      uint256 prevBalStaker = ctx.balanceOf(address(this));

      // Delegate
      uint256 totalAmount = amount + amount2;
      ctx.approve(address(delegatorFactory), totalAmount);
      delegatorFactory.stake(delegator, totalAmount);

      // Time Skip
      hevm.warp(waitTime + 1 seconds);

      // Remove Delegate
      delegatorFactory.withdraw(delegator, amount);
      uint256 balDelegatee = ctx.balanceOf(delegatee);
      uint256 balDelegator = ctx.balanceOf(delegator);
      assertEq(ctx.balanceOf(address(this)), prevBalStaker - amount2);
      assertEq(balDelegatee, 0);
      assertEq(balDelegator, amount2);
      assertEq(ctx.getCurrentVotes(delegatee), amount2);
      assertEq(amount2, delegatorFactory.balanceOf(address(this)));
      assertEq(amount2, delegatorFactory.totalSupply());

      // Remove Delegate
      delegatorFactory.withdraw(delegator, amount2);
      balDelegatee = ctx.balanceOf(delegatee);
      balDelegator = ctx.balanceOf(delegator);
      assertEq(ctx.balanceOf(address(this)), prevBalStaker);
      assertEq(balDelegatee, 0);
      assertEq(balDelegator, 0);
      assertEq(ctx.getCurrentVotes(delegatee), 0);
      assertEq(0, delegatorFactory.balanceOf(address(this)));
      assertEq(0, delegatorFactory.totalSupply());
   }

   function testFail_invalidRemoveDelegator() public {
      uint256 amount = 1 ether;
      FakeDelegator faker = new FakeDelegator();
      user1.doRemoveDelegate(delegatorFactory, address(faker), amount);
   }

   function testFail_invalidRemoveAmount() public {
      address delegatee = address(0x1);
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);
      // Time Skip
      hevm.warp(waitTime + 1 seconds);
      delegatorFactory.withdraw(delegator, 0);
   }

   function testFail_invalidUnDelegateAmount(address delegatee, uint256 amount)
      public
   {
      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);

      // Delegate
      ctx.approve(address(delegatorFactory), amount);
      delegatorFactory.stake(delegator, amount);

      // Time Skip
      hevm.warp(waitTime + 1 seconds);

      // Remove Delegate
      delegatorFactory.withdraw(delegator, (amount + 1));
   }

   function test_moveDelegation(uint256 amount, uint256 amount2) public {
      if (amount > ctx.totalSupply() / 2 || amount2 > ctx.totalSupply() / 2)
         return;
      if (amount == 0 || amount2 == 0) return;

      uint256 prevBalStaker = ctx.balanceOf(address(this));
      address delegatee1 = address(0x1);
      address delegatee2 = address(0x2);
      delegatorFactory.createDelegator(delegatee1);
      delegatorFactory.createDelegator(delegatee2);
      address delegator1 = delegatorFactory.delegateeToDelegator(delegatee1);
      address delegator2 = delegatorFactory.delegateeToDelegator(delegatee2);
      uint256 totalAmount = amount + amount2;
      ctx.approve(address(delegatorFactory), totalAmount);
      delegatorFactory.stake(delegator1, totalAmount);

      // Time Skip
      hevm.warp(waitTime + 1 seconds);

      delegatorFactory.withdraw(delegator1, amount);
      ctx.approve(address(delegatorFactory), amount);
      delegatorFactory.stake(delegator2, amount);

      assertEq(
         ctx.balanceOf(address(this)),
         prevBalStaker - (amount + amount2)
      );
      assertEq(ctx.balanceOf(delegator1), amount2);
      assertEq(ctx.balanceOf(delegator2), amount);
      assertEq(ctx.getCurrentVotes(delegatee1), amount2);
      assertEq(ctx.getCurrentVotes(delegatee2), amount);
      assertEq(
         delegatorFactory.stakerWaitTime(address(this), delegator2),
         2 weeks + 1 seconds
      );
      assertEq(amount2 + amount, delegatorFactory.balanceOf(address(this)));
      assertEq(amount2 + amount, delegatorFactory.totalSupply());
   }

   function test_updateWaitTime() public {
      uint256 newTime = 1 weeks;
      assertEq(delegatorFactory.waitTime(), waitTime);
      delegatorFactory.updateWaitTime(newTime);
      assertEq(delegatorFactory.waitTime(), newTime);
   }

   function test_updateWaitTimeFuzz(uint256 newTime) public {
      assertEq(delegatorFactory.waitTime(), waitTime);
      delegatorFactory.updateWaitTime(newTime);
      assertEq(delegatorFactory.waitTime(), newTime);
   }

   function testFail_updateWaitTimeNotAdmin(uint256 newTime) public {
      user1.doUpdateWaitTime(delegatorFactory, newTime);
   }

   function test_notifyRewards() public {
      uint256 reward = 1 ether;
      ctx.transfer(address(delegatorFactory), reward);
      delegatorFactory.notifyRewardAmount(reward);

      ctx.transfer(address(delegatorFactory), reward);
      delegatorFactory.notifyRewardAmount(reward);
   }

   function test_notifyRewardsFuzz(uint256 reward) public {
      if (reward > ctx.totalSupply()) return;
      if (reward == 0) return;
      ctx.transfer(address(delegatorFactory), reward);
      delegatorFactory.notifyRewardAmount(reward);
   }

   function testFail_notifyRewards_rewardToHigh() public {
      delegatorFactory.notifyRewardAmount(1 ether);
   }

   function testFail_notifyRewards_notOwner() public {
      user1.doUpdateRewards(delegatorFactory, 1 ether);
   }

   function test_setRewardsDuration() public {
      uint256 duration = 1 weeks;
      hevm.warp(delegatorFactory.periodFinish() + 1);
      delegatorFactory.setRewardsDuration(duration);
      uint256 rewardsDuration = delegatorFactory.rewardsDuration();
      assert(rewardsDuration == duration);
   }

   function test_setRewardsDurationFuzz(uint256 duration) public {
      hevm.warp(delegatorFactory.periodFinish() + 1);
      delegatorFactory.setRewardsDuration(duration);
      uint256 rewardsDuration = delegatorFactory.rewardsDuration();
      assert(rewardsDuration == duration);
   }

   function testFail_setRewardsDuration_notOwner() public {
      user1.doSetRewardsDuration(delegatorFactory, 1 weeks);
   }

   function testFail_setRewardsDuration_rewardsNotComplete(uint256 duration)
      public
   {
      delegatorFactory.setRewardsDuration(duration);
      delegatorFactory.setRewardsDuration(duration);
   }

   function test_earnRewards() public {
      uint256 amount = 1 ether;
      address delegatee = address(0x1);
      uint256 lastUpdateTime = delegatorFactory.lastUpdateTime();
      uint256 lastRewardPerTokenStored = delegatorFactory
         .rewardPerTokenStored();
      uint256 lastUserRewardPerTokenPaid = delegatorFactory
         .userRewardPerTokenPaid(address(user1));

      assertEq(lastUpdateTime, 0);
      assertEq(lastRewardPerTokenStored, 0);
      assertEq(lastUserRewardPerTokenPaid, 0);

      // create delegator
      delegatorFactory.createDelegator(delegatee);
      address delegator = delegatorFactory.delegateeToDelegator(delegatee);
      address delegateeResult = delegatorFactory.delegatorToDelegatee(
         delegator
      );
      assertEq(delegateeResult, delegatee);
      assertTrue(delegatorFactory.delegators(delegator));

      // Delegate
      ctx.transfer(address(user1), amount);
      user1.approveAmount(ctx, delegatorFactory, amount);
      user1.doDelegate(delegatorFactory, delegator, amount / 2);
      hevm.warp(2 days);
      assertEq(delegatorFactory.earned(address(user1)), 0);
      assertEq(delegatorFactory.rewards(address(user1)), 0);

      // Start Rewards
      uint256 reward = 250000 ether;
      ctx.transfer(address(delegatorFactory), reward);
      delegatorFactory.notifyRewardAmount(reward);

      // check if rewards increase
      uint256 prevReward = delegatorFactory.earned(address(user1));
      assertEq(prevReward, 0);

      hevm.warp(1 weeks);
      uint256 newReward = delegatorFactory.earned(address(user1));
      assertTrue(newReward > prevReward);
      prevReward = newReward;
      user1.doDelegate(delegatorFactory, delegator, amount / 2);
      assert(delegatorFactory.rewards(address(user1)) > 0);

      hevm.warp(2 weeks);
      newReward = delegatorFactory.earned(address(user1));
      assertTrue(newReward > prevReward);
      prevReward = newReward;
      uint256 prevBal = ctx.balanceOf(address(user1));
      user1.doClaimRewards(delegatorFactory);
      uint256 newBal = ctx.balanceOf(address(user1));
      uint256 updateTime = delegatorFactory.lastUpdateTime();
      uint256 rewardPerTokenStored = delegatorFactory.rewardPerTokenStored();
      uint256 userRewardPerTokenPaid = delegatorFactory.userRewardPerTokenPaid(
         address(user1)
      );

      assertTrue(newBal > prevBal);
      assert(updateTime > lastUpdateTime);
      assertEq(updateTime, block.timestamp);
      assert(rewardPerTokenStored > lastRewardPerTokenStored);
      assert(userRewardPerTokenPaid > lastRewardPerTokenStored);

      // warp to end
      hevm.warp(delegatorFactory.rewardsDuration());
      newReward = delegatorFactory.earned(address(user1));
      assertTrue(newReward > prevReward);

      // claim rewards
      prevBal = ctx.balanceOf(address(user1));
      user1.doClaimRewards(delegatorFactory);
      newBal = ctx.balanceOf(address(user1));
      assertTrue(newBal > prevBal);
      assertEq(delegatorFactory.rewards(address(user1)), 0);
   }
}
