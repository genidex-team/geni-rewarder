# 🏆 GeniRewarder – GENI Token Reward Distribution System

GeniRewarder is a smart contract system that distributes GENI token rewards to users based on their trading activity. The reward is fairly distributed over time according to a point-based system and an epoch-based unlock mechanism.

---

## 🚀 Features

- ⏱️ Epoch-based reward distribution (12-month cycles)
- 🔓 Tokens unlock gradually every minute
- 🧮 1 USD of trading = 1 reward point
- 🎁 Claim rewards anytime based on point share and unlocked tokens
- 🔐 Supports manual token contributions

---

## 📊 How It Works

1. 💰 Users trade → earn points (1 USD = 1 point)
2. 📥 Admin or users contribute GENI tokens via `contribute()`
3. 📆 At the start of each epoch, 50% of the current contract balance is marked as unlockable and will be gradually distributed throughout the entire 12-month epoch.
4. ⏳ Tokens unlock linearly every minute
5. 🧾 Users can claim rewards at any time based on their share of total unclaimed points

---

## 📚 Useful Contracts & Functions

- `claim(uint256 pointsToClaim)`
- `getUserRewardInfo(address)`
- `getSystemRewardInfo()`
- `contribute(uint256)`

---

## ⚖️ License

MIT License
