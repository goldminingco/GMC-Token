use anchor_lang::prelude::*;
use crate::{UserStakeInfo, StakingError};

pub fn calculate_affiliate_boost(
    user_stake_info: &Account<UserStakeInfo>,
    accounts: &[AccountInfo],
) -> Result<u8> {
    let mut total_boost = 0;
    let mut visited = Vec::new();

    for (level, child_pubkey) in user_stake_info.children.iter().enumerate() {
        if level >= 6 {
            break;
        }

        let child_stake_info = get_user_stake_info(child_pubkey, accounts)?;
        total_boost += calculate_level_boost(child_stake_info, accounts, level + 1, &mut visited)?;
    }

    Ok(total_boost)
}

fn calculate_level_boost(
    user_stake_info: &Account<UserStakeInfo>,
    accounts: &[AccountInfo],
    level: usize,
    visited: &mut Vec<Pubkey>,
) -> Result<u8> {
    if level > 6 {
        return Ok(0);
    }

    if visited.contains(&user_stake_info.key()) {
        return Err(StakingError::CircularReferenceDetected.into());
    }

    visited.push(user_stake_info.key());

    let mut level_boost = 0;

    // This is a placeholder for the actual boost calculation.
    // The actual calculation will depend on the staking power of the user.
    level_boost += 1;

    for child_pubkey in &user_stake_info.children {
        let child_stake_info = get_user_stake_info(child_pubkey, accounts)?;
        level_boost += calculate_level_boost(child_stake_info, accounts, level + 1, visited)?;
    }

    Ok(level_boost)
}

fn get_user_stake_info<'a>(
    pubkey: &Pubkey,
    accounts: &'a [AccountInfo<'a>],
) -> Result<Account<'a, UserStakeInfo>> {
    for account_info in accounts {
        if account_info.key == pubkey {
            return Account::try_from(account_info);
        }
    }

    Err(StakingError::MissingRankingProgram.into()) // TODO: change this error
}
