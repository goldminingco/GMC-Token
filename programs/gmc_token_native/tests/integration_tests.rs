// 🛡️ GMC Token Native Rust Integration Tests
// Security-First Integration Testing with TDD + OWASP + DevSecOps
// 
// These tests validate the complete program behavior in a simulated Solana environment

use solana_program::{
    instruction::{AccountMeta, Instruction},
    pubkey::Pubkey,
    rent::Rent,
};
use solana_program_test::*;
use solana_sdk::{
    account::Account,
    signature::{Keypair, Signer},
    transaction::Transaction,
};


use gmc_token_native::{
    GMCInstruction, GMCTokenConfig,
    calculate_transfer_fee, id,
};

// 🛡️ Test utilities for security validation
struct TestContext {
    pub program_id: Pubkey,
    pub authority: Keypair,
    pub mint: Keypair,
    pub config_account: Keypair,
    #[allow(dead_code)]
    pub user_account: Keypair,
}

impl TestContext {
    pub fn new() -> Self {
        Self {
            program_id: id(),
            authority: Keypair::new(),
            mint: Keypair::new(),
            config_account: Keypair::new(),
            user_account: Keypair::new(),
        }
    }
}

// 🧪 TDD Integration Test: Initialize Token
#[tokio::test]
async fn test_initialize_token_success() {
    // 🔴 RED: Define expected behavior
    let mut program_test = ProgramTest::new(
        "gmc_token_native",
        id(),
        processor!(gmc_token_native::process_instruction),
    );

    let test_ctx = TestContext::new();
    
    // Add required accounts
    program_test.add_account(
        test_ctx.authority.pubkey(),
        Account {
            lamports: 1_000_000_000,
            data: vec![],
            owner: solana_program::system_program::id(),
            executable: false,
            rent_epoch: 0,
        },
    );

    program_test.add_account(
        test_ctx.config_account.pubkey(),
        Account {
            lamports: Rent::default().minimum_balance(GMCTokenConfig::LEN),
            data: vec![0; GMCTokenConfig::LEN],
            owner: test_ctx.program_id,
            executable: false,
            rent_epoch: 0,
        },
    );

    let (mut banks_client, payer, recent_blockhash) = program_test.start().await;

    // 🛡️ OWASP SC04: Test with valid authority signature
    let initialize_instruction = Instruction {
        program_id: test_ctx.program_id,
        accounts: vec![
            AccountMeta::new(test_ctx.authority.pubkey(), true),
            AccountMeta::new(test_ctx.mint.pubkey(), false),
            AccountMeta::new(test_ctx.config_account.pubkey(), false),
            AccountMeta::new_readonly(solana_program::sysvar::rent::id(), false),
            AccountMeta::new_readonly(spl_token::id(), false),
        ],
        data: GMCInstruction::InitializeToken {
            transfer_fee_basis_points: 50, // 0.5%
            maximum_fee: 1_000_000,
            burn_address: Pubkey::new_unique(),
            staking_pool: Pubkey::new_unique(),
            ranking_pool: Pubkey::new_unique(),
        }.try_to_vec().unwrap(),
    };

    let mut transaction = Transaction::new_with_payer(
        &[initialize_instruction],
        Some(&payer.pubkey()),
    );
    transaction.sign(&[&payer, &test_ctx.authority], recent_blockhash);

    // 🟢 GREEN: Execute and verify success
    let result = banks_client.process_transaction(transaction).await;
    assert!(result.is_ok(), "Initialize token should succeed");

    // 🛡️ Verify configuration was set correctly
    let config_account = banks_client
        .get_account(test_ctx.config_account.pubkey())
        .await
        .unwrap()
        .unwrap();

    let config_data = GMCTokenConfig::try_from_slice(&config_account.data).unwrap();
    assert_eq!(config_data.transfer_fee_basis_points, 50);
    assert_eq!(config_data.maximum_fee, 1_000_000);
    assert!(config_data.is_initialized);
    assert!(!config_data.is_paused);
}

// 🛡️ OWASP SC04: Access Control Test - Unauthorized initialization
#[tokio::test]
async fn test_initialize_token_unauthorized_fails() {
    let mut program_test = ProgramTest::new(
        "gmc_token_native",
        id(),
        processor!(gmc_token_native::process_instruction),
    );

    let test_ctx = TestContext::new();
    let unauthorized_user = Keypair::new();

    program_test.add_account(
        unauthorized_user.pubkey(),
        Account {
            lamports: 1_000_000_000,
            data: vec![],
            owner: solana_program::system_program::id(),
            executable: false,
            rent_epoch: 0,
        },
    );

    program_test.add_account(
        test_ctx.config_account.pubkey(),
        Account {
            lamports: Rent::default().minimum_balance(GMCTokenConfig::LEN),
            data: vec![0; GMCTokenConfig::LEN],
            owner: test_ctx.program_id,
            executable: false,
            rent_epoch: 0,
        },
    );

    let (mut banks_client, payer, recent_blockhash) = program_test.start().await;

    // 🚨 Try to initialize with unauthorized user (authority not signing)
    let initialize_instruction = Instruction {
        program_id: test_ctx.program_id,
        accounts: vec![
            AccountMeta::new(unauthorized_user.pubkey(), false), // Authority not signing!
            AccountMeta::new(test_ctx.mint.pubkey(), false),
            AccountMeta::new(test_ctx.config_account.pubkey(), false),
            AccountMeta::new_readonly(solana_program::sysvar::rent::id(), false),
            AccountMeta::new_readonly(spl_token::id(), false),
        ],
        data: GMCInstruction::InitializeToken {
            transfer_fee_basis_points: 50,
            maximum_fee: 1_000_000,
            burn_address: Pubkey::new_unique(),
            staking_pool: Pubkey::new_unique(),
            ranking_pool: Pubkey::new_unique(),
        }.try_to_vec().unwrap(),
    };

    let mut transaction = Transaction::new_with_payer(
        &[initialize_instruction],
        Some(&payer.pubkey()),
    );
    transaction.sign(&[&payer], recent_blockhash); // Only payer signs, not authority

    // 🛡️ Should fail due to unauthorized access
    let result = banks_client.process_transaction(transaction).await;
    assert!(result.is_err(), "Unauthorized initialization should fail");
}

// 🛡️ OWASP SC02: Integer Overflow Test - Invalid fee basis points
#[tokio::test]
async fn test_initialize_token_invalid_fee_fails() {
    let mut program_test = ProgramTest::new(
        "gmc_token_native",
        id(),
        processor!(gmc_token_native::process_instruction),
    );

    let test_ctx = TestContext::new();
    
    program_test.add_account(
        test_ctx.authority.pubkey(),
        Account {
            lamports: 1_000_000_000,
            data: vec![],
            owner: solana_program::system_program::id(),
            executable: false,
            rent_epoch: 0,
        },
    );

    program_test.add_account(
        test_ctx.config_account.pubkey(),
        Account {
            lamports: Rent::default().minimum_balance(GMCTokenConfig::LEN),
            data: vec![0; GMCTokenConfig::LEN],
            owner: test_ctx.program_id,
            executable: false,
            rent_epoch: 0,
        },
    );

    let (mut banks_client, payer, recent_blockhash) = program_test.start().await;

    // 🚨 Try to initialize with invalid fee (> 100%)
    let initialize_instruction = Instruction {
        program_id: test_ctx.program_id,
        accounts: vec![
            AccountMeta::new(test_ctx.authority.pubkey(), true),
            AccountMeta::new(test_ctx.mint.pubkey(), false),
            AccountMeta::new(test_ctx.config_account.pubkey(), false),
            AccountMeta::new_readonly(solana_program::sysvar::rent::id(), false),
            AccountMeta::new_readonly(spl_token::id(), false),
        ],
        data: GMCInstruction::InitializeToken {
            transfer_fee_basis_points: 10001, // > 100% - Invalid!
            maximum_fee: 1_000_000,
            burn_address: Pubkey::new_unique(),
            staking_pool: Pubkey::new_unique(),
            ranking_pool: Pubkey::new_unique(),
        }.try_to_vec().unwrap(),
    };

    let mut transaction = Transaction::new_with_payer(
        &[initialize_instruction],
        Some(&payer.pubkey()),
    );
    transaction.sign(&[&payer, &test_ctx.authority], recent_blockhash);

    // 🛡️ Should fail due to invalid fee
    let result = banks_client.process_transaction(transaction).await;
    assert!(result.is_err(), "Invalid fee initialization should fail");
}

// 🛡️ OWASP SC06: DoS Protection Test - Emergency pause functionality
#[tokio::test]
async fn test_emergency_pause_and_resume() {
    let mut program_test = ProgramTest::new(
        "gmc_token_native",
        id(),
        processor!(gmc_token_native::process_instruction),
    );

    let test_ctx = TestContext::new();
    
    // Setup initialized config
    let config_data = GMCTokenConfig {
        mint: test_ctx.mint.pubkey(),
        authority: test_ctx.authority.pubkey(),
        transfer_fee_basis_points: 50,
        maximum_fee: 1_000_000,
        burn_address: Pubkey::new_unique(),
        staking_pool: Pubkey::new_unique(),
        ranking_pool: Pubkey::new_unique(),
        total_burned: 0, // ➕ Adicionar campo faltante
        is_initialized: true,
        is_paused: false,
    };

    program_test.add_account(
        test_ctx.authority.pubkey(),
        Account {
            lamports: 1_000_000_000,
            data: vec![],
            owner: solana_program::system_program::id(),
            executable: false,
            rent_epoch: 0,
        },
    );

    program_test.add_account(
        test_ctx.config_account.pubkey(),
        Account {
            lamports: Rent::default().minimum_balance(GMCTokenConfig::LEN),
            data: config_data.try_to_vec().unwrap(),
            owner: test_ctx.program_id,
            executable: false,
            rent_epoch: 0,
        },
    );

    let (mut banks_client, payer, recent_blockhash) = program_test.start().await;

    // 🛡️ Test emergency pause
    let pause_instruction = Instruction {
        program_id: test_ctx.program_id,
        accounts: vec![
            AccountMeta::new(test_ctx.authority.pubkey(), true),
            AccountMeta::new(test_ctx.config_account.pubkey(), false),
        ],
        data: GMCInstruction::EmergencyPause.try_to_vec().unwrap(),
    };

    let mut transaction = Transaction::new_with_payer(
        &[pause_instruction],
        Some(&payer.pubkey()),
    );
    transaction.sign(&[&payer, &test_ctx.authority], recent_blockhash);

    let result = banks_client.process_transaction(transaction).await;
    assert!(result.is_ok(), "Emergency pause should succeed");

    // 🛡️ Verify contract is paused
    let config_account = banks_client
        .get_account(test_ctx.config_account.pubkey())
        .await
        .unwrap()
        .unwrap();

    let updated_config = GMCTokenConfig::try_from_slice(&config_account.data).unwrap();
    assert!(updated_config.is_paused, "Contract should be paused");

    // 🛡️ Test resume
    let resume_instruction = Instruction {
        program_id: test_ctx.program_id,
        accounts: vec![
            AccountMeta::new(test_ctx.authority.pubkey(), true),
            AccountMeta::new(test_ctx.config_account.pubkey(), false),
        ],
        data: GMCInstruction::Resume.try_to_vec().unwrap(),
    };

    let mut transaction = Transaction::new_with_payer(
        &[resume_instruction],
        Some(&payer.pubkey()),
    );
    transaction.sign(&[&payer, &test_ctx.authority], recent_blockhash);

    let result = banks_client.process_transaction(transaction).await;
    assert!(result.is_ok(), "Resume should succeed");

    // 🛡️ Verify contract is resumed
    let config_account = banks_client
        .get_account(test_ctx.config_account.pubkey())
        .await
        .unwrap()
        .unwrap();

    let final_config = GMCTokenConfig::try_from_slice(&config_account.data).unwrap();
    assert!(!final_config.is_paused, "Contract should be resumed");
}

// 🛡️ OWASP SC02: Arithmetic Security Test - Fee calculation edge cases
#[tokio::test]
async fn test_fee_calculation_edge_cases() {
    // Test zero amount
    let fee = calculate_transfer_fee(0, 50).unwrap();
    assert_eq!(fee, 0, "Fee for zero amount should be zero");

    // Test maximum safe amount
    let max_safe = u64::MAX / 10000;
    let fee = calculate_transfer_fee(max_safe, 50).unwrap();
    assert!(fee > 0, "Fee should be calculated for max safe amount");

    // Test overflow protection
    let result = calculate_transfer_fee(u64::MAX, 50);
    assert!(result.is_err(), "Should detect overflow");

    // Test invalid basis points
    let result = calculate_transfer_fee(1000, 10001);
    assert!(result.is_err(), "Should reject invalid basis points");
}

// 🛡️ OWASP SC05: Input Validation Test - Malformed instruction data
#[tokio::test]
async fn test_malformed_instruction_data() {
    let mut program_test = ProgramTest::new(
        "gmc_token_native",
        id(),
        processor!(gmc_token_native::process_instruction),
    );

    let test_ctx = TestContext::new();
    
    program_test.add_account(
        test_ctx.authority.pubkey(),
        Account {
            lamports: 1_000_000_000,
            data: vec![],
            owner: solana_program::system_program::id(),
            executable: false,
            rent_epoch: 0,
        },
    );

    let (mut banks_client, payer, recent_blockhash) = program_test.start().await;

    // 🚨 Test with empty instruction data
    let malformed_instruction = Instruction {
        program_id: test_ctx.program_id,
        accounts: vec![
            AccountMeta::new(test_ctx.authority.pubkey(), true),
        ],
        data: vec![], // Empty data - should fail
    };

    let mut transaction = Transaction::new_with_payer(
        &[malformed_instruction],
        Some(&payer.pubkey()),
    );
    transaction.sign(&[&payer, &test_ctx.authority], recent_blockhash);

    let result = banks_client.process_transaction(transaction).await;
    assert!(result.is_err(), "Empty instruction data should fail");

    // 🚨 Test with invalid instruction data
    let malformed_instruction = Instruction {
        program_id: test_ctx.program_id,
        accounts: vec![
            AccountMeta::new(test_ctx.authority.pubkey(), true),
        ],
        data: vec![0xFF, 0xFF, 0xFF], // Invalid data - should fail
    };

    let mut transaction = Transaction::new_with_payer(
        &[malformed_instruction],
        Some(&payer.pubkey()),
    );
    transaction.sign(&[&payer, &test_ctx.authority], recent_blockhash);

    let result = banks_client.process_transaction(transaction).await;
    assert!(result.is_err(), "Invalid instruction data should fail");
}

// 🛡️ Security Stress Test - Multiple operations
#[tokio::test]
async fn test_security_stress_multiple_operations() {
    let mut program_test = ProgramTest::new(
        "gmc_token_native",
        id(),
        processor!(gmc_token_native::process_instruction),
    );

    let test_ctx = TestContext::new();
    
    program_test.add_account(
        test_ctx.authority.pubkey(),
        Account {
            lamports: 1_000_000_000,
            data: vec![],
            owner: solana_program::system_program::id(),
            executable: false,
            rent_epoch: 0,
        },
    );

    program_test.add_account(
        test_ctx.config_account.pubkey(),
        Account {
            lamports: Rent::default().minimum_balance(GMCTokenConfig::LEN),
            data: vec![0; GMCTokenConfig::LEN],
            owner: test_ctx.program_id,
            executable: false,
            rent_epoch: 0,
        },
    );

    let (mut banks_client, payer, recent_blockhash) = program_test.start().await;

    // 🛡️ Perform multiple operations in sequence
    let operations = vec![
        // Initialize
        GMCInstruction::InitializeToken {
            transfer_fee_basis_points: 50,
            maximum_fee: 1_000_000,
            burn_address: Pubkey::new_unique(),
            staking_pool: Pubkey::new_unique(),
            ranking_pool: Pubkey::new_unique(),
        },
        // Pause
        GMCInstruction::EmergencyPause,
        // Resume
        GMCInstruction::Resume,
        // Pause again
        GMCInstruction::EmergencyPause,
        // Resume again
        GMCInstruction::Resume,
    ];

    for (i, operation) in operations.iter().enumerate() {
        let accounts = match operation {
            GMCInstruction::InitializeToken { .. } => vec![
                AccountMeta::new(test_ctx.authority.pubkey(), true),
                AccountMeta::new(test_ctx.mint.pubkey(), false),
                AccountMeta::new(test_ctx.config_account.pubkey(), false),
                AccountMeta::new_readonly(solana_program::sysvar::rent::id(), false),
                AccountMeta::new_readonly(spl_token::id(), false),
            ],
            _ => vec![
                AccountMeta::new(test_ctx.authority.pubkey(), true),
                AccountMeta::new(test_ctx.config_account.pubkey(), false),
            ],
        };

        let instruction = Instruction {
            program_id: test_ctx.program_id,
            accounts,
            data: operation.try_to_vec().unwrap(),
        };

        let mut transaction = Transaction::new_with_payer(
            &[instruction],
            Some(&payer.pubkey()),
        );
        transaction.sign(&[&payer, &test_ctx.authority], recent_blockhash);

        let result = banks_client.process_transaction(transaction).await;
        assert!(result.is_ok(), "Operation {} should succeed", i);
    }

    println!("✅ All security stress test operations completed successfully");
}
