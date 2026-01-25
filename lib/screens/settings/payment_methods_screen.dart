import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../services/api_service.dart';
import '../../widgets/app_header.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  // Bank Account Management
  List<Map<String, dynamic>> _bankAccounts = [];
  bool _isLoadingBankAccounts = false;
  final TextEditingController _accountHolderNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscCodeController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _branchNameController = TextEditingController();
  
  // Wallet & Withdrawal
  double? _walletBalance;
  bool _isLoadingWallet = false;

  @override
  void initState() {
    super.initState();
    _loadBankAccounts(forceRefresh: false);
    _loadWalletBalance(forceRefresh: false);
  }

  @override
  void dispose() {
    _accountHolderNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _bankNameController.dispose();
    _branchNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBankAccounts({bool forceRefresh = false}) async {
    setState(() => _isLoadingBankAccounts = true);
    final result = await ApiService.getBankAccounts(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _isLoadingBankAccounts = false;
        if (result['success'] == true) {
          final data = result['data'];
          print('🏦 Loaded bank accounts data: $data');
          print('🏦 Data type: ${data.runtimeType}');
          
          if (data is List) {
            _bankAccounts = List<Map<String, dynamic>>.from(
              data.map((item) => item is Map ? Map<String, dynamic>.from(item) : {}),
            );
          } else {
            _bankAccounts = [];
          }
          
          print('🏦 Final bank accounts list: $_bankAccounts');
          print('🏦 Number of accounts: ${_bankAccounts.length}');
        } else {
          print('❌ Failed to load bank accounts: ${result['error']}');
          _bankAccounts = [];
        }
      });
    }
  }

  Future<void> _loadWalletBalance({bool forceRefresh = false}) async {
    setState(() => _isLoadingWallet = true);
    final result = await ApiService.getWalletBalance(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _isLoadingWallet = false;
        if (result['success'] == true) {
          _walletBalance = result['balance']?.toDouble();
        }
      });
    }
  }

  Future<void> _addBankAccount() async {
    if (!mounted) return;
    
    final accountHolderName = _accountHolderNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final ifscCode = _ifscCodeController.text.trim();
    final bankName = _bankNameController.text.trim();
    final branchName = _branchNameController.text.trim();

    if (accountHolderName.isEmpty || accountNumber.isEmpty || ifscCode.isEmpty || bankName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    print('🏦 Attempting to add bank account...');
    final result = await ApiService.addBankAccount(
      accountHolderName: accountHolderName,
      accountNumber: accountNumber,
      ifscCode: ifscCode,
      bankName: bankName,
      branchName: branchName.isNotEmpty ? branchName : null,
    );

    if (!mounted) return;

    print('🏦 Add bank account result: $result');

    if (result['success'] == true) {
      _accountHolderNameController.clear();
      _accountNumberController.clear();
      _ifscCodeController.clear();
      _bankNameController.clear();
      _branchNameController.clear();
      await _loadBankAccounts(forceRefresh: true); // Force refresh after adding
      
      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank account added successfully')),
      );
    } else {
      if (!mounted) return;
      // Extract error message from different possible formats
      String errorMessage = 'Failed to add bank account';
      if (result['error'] != null) {
        if (result['error'] is Map) {
          errorMessage = result['error']['message'] ?? 
                        result['error']['detail'] ?? 
                        result['error'].toString();
        } else if (result['error'] is String) {
          errorMessage = result['error'];
        }
      }
      
      print('❌ Bank account error: $errorMessage');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _deleteBankAccount(int accountId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bank Account'),
        content: const Text('Are you sure you want to delete this bank account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

      // Optimistic update: Remove bank account from list immediately
      final previousAccounts = List<Map<String, dynamic>>.from(_bankAccounts);
      setState(() {
        _bankAccounts = _bankAccounts.where((a) => a['id'] != accountId).toList();
      });

      final result = await ApiService.deleteBankAccount(accountId);
    if (mounted) {
      if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bank account deleted successfully')),
          );
          _loadBankAccounts(forceRefresh: true); // Force refresh after delete
        } else {
          // Revert optimistic update on error
          setState(() {
            _bankAccounts = previousAccounts;
          });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?['message'] ?? 'Failed to delete bank account')),
        );
      }
    }
  }


  Future<void> _showAddBankAccountDialog() async {
    _accountHolderNameController.clear();
    _accountNumberController.clear();
    _ifscCodeController.clear();
    _bankNameController.clear();
    _branchNameController.clear();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: context.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Bank Account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.foregroundColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Iconsax.close_circle, color: context.mutedForegroundColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _accountHolderNameController,
                  decoration: InputDecoration(
                    labelText: 'Account Holder Name *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountNumberController,
                  decoration: InputDecoration(
                    labelText: 'Account Number *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ifscCodeController,
                  decoration: InputDecoration(
                    labelText: 'IFSC Code *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bankNameController,
                  decoration: InputDecoration(
                    labelText: 'Bank Name *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _branchNameController,
                  decoration: InputDecoration(
                    labelText: 'Branch Name (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _addBankAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Add Bank Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showWithdrawalDialog() async {
    if (_bankAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a bank account first')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => _WithdrawalDialog(
        bankAccounts: _bankAccounts,
        walletBalance: _walletBalance ?? 0,
        onWithdraw: (bankAccountId, amount) async {
          final result = await ApiService.withdrawMoney(bankAccountId, amount);
          if (mounted) {
            Navigator.pop(context);
            if (result['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Withdrawal request submitted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              _loadWalletBalance(forceRefresh: false);
              _loadBankAccounts(forceRefresh: false);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['error']?['message'] ?? 'Withdrawal failed'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(title: 'Payment Methods'),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wallet Balance
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wallet Balance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.mutedForegroundColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _isLoadingWallet
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    'Rs. ${(_walletBalance ?? 0).toStringAsFixed(2)}/-',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                            ],
                          ),
                          if (_walletBalance != null && _walletBalance! > 0)
                            ElevatedButton.icon(
                              onPressed: _showWithdrawalDialog,
                              icon: const Icon(Iconsax.arrow_down, size: 16),
                              label: const Text('Withdraw'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                        ],
                      ),
                    ).animate(delay: 100.ms).fadeIn(duration: 500.ms).moveY(begin: 20, end: 0),
                    
                    const SizedBox(height: 24),
                    
                    // Bank Accounts List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bank Accounts',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: context.foregroundColor,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddBankAccountDialog,
                          icon: const Icon(Iconsax.add, size: 16),
                          label: const Text('Add Account'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _isLoadingBankAccounts
                      ? const Center(child: CircularProgressIndicator())
                      : _bankAccounts.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(
                              children: [
                                Icon(Iconsax.bank, size: 48, color: context.mutedForegroundColor),
                                const SizedBox(height: 12),
                                Text(
                                  'No bank accounts added',
                                  style: TextStyle(color: context.mutedForegroundColor),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add a bank account to receive payments',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.mutedForegroundColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: _bankAccounts.map((account) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (account['is_primary'] ?? false) 
                                      ? AppColors.primary 
                                      : context.borderColor,
                                    width: (account['is_primary'] ?? false) ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Iconsax.bank,
                                      color: (account['is_primary'] ?? false) 
                                        ? AppColors.primary 
                                        : context.mutedForegroundColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  account['bank_name'] ?? 'Bank',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: context.foregroundColor,
                                                  ),
                                                ),
                                              ),
                                              if (account['is_primary'] ?? false)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Primary',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.primary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${account['account_holder_name']} • ${account['account_number']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.mutedForegroundColor,
                                            ),
                                          ),
                                          Text(
                                            'IFSC: ${account['ifsc_code']}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: context.mutedForegroundColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Iconsax.trash, color: Colors.red, size: 20),
                                      onPressed: () => _deleteBankAccount(account['id']),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Separate StatefulWidget for withdrawal dialog to manage its own controller
class _WithdrawalDialog extends StatefulWidget {
  final List<Map<String, dynamic>> bankAccounts;
  final double walletBalance;
  final Function(int, double) onWithdraw;

  const _WithdrawalDialog({
    required this.bankAccounts,
    required this.walletBalance,
    required this.onWithdraw,
  });

  @override
  State<_WithdrawalDialog> createState() => _WithdrawalDialogState();
}

class _WithdrawalDialogState extends State<_WithdrawalDialog> {
  final TextEditingController _amountController = TextEditingController();
  int? _selectedBankAccountId;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Withdraw Money',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.foregroundColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Iconsax.close_circle, color: context.mutedForegroundColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Available Balance: Rs. ${widget.walletBalance.toStringAsFixed(2)}/-',
                style: TextStyle(
                  fontSize: 14,
                  color: context.mutedForegroundColor,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount (Rs.)',
                  prefixText: 'Rs. ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.borderColor),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Text(
                'Select Bank Account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.foregroundColor,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.bankAccounts.map((account) {
                final isSelected = _selectedBankAccountId == account['id'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedBankAccountId = account['id'];
                    });
                  },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? AppColors.primary.withOpacity(0.1)
                            : context.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected 
                              ? AppColors.primary 
                              : context.borderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Iconsax.tick_circle : Iconsax.bank,
                              color: isSelected ? AppColors.primary : context.mutedForegroundColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account['bank_name'] ?? 'Bank',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: context.foregroundColor,
                                    ),
                                  ),
                                  Text(
                                    '${account['account_number']} • ${account['ifsc_code']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.mutedForegroundColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_selectedBankAccountId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a bank account')),
                    );
                    return;
                  }
                  
                  final amountText = _amountController.text.trim();
                  if (amountText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an amount')),
                    );
                    return;
                  }
                  
                  final amount = double.tryParse(amountText);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }
                  
                  if (amount > widget.walletBalance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Insufficient balance. Available: Rs. ${widget.walletBalance.toStringAsFixed(2)}/-',
                        ),
                      ),
                    );
                    return;
                  }
                  
                  widget.onWithdraw(_selectedBankAccountId!, amount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Withdraw (Simulation)'),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: This is a simulation. Money will be transferred instantly.',
                style: TextStyle(
                  fontSize: 11,
                  color: context.mutedForegroundColor,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

