import 'package:flutter/material.dart';
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

class SendCredexScreen extends StatefulWidget {
  static const String routeName = '/send-credex';
  final DashboardAccount senderAccount;
  final AccountRepository accountRepository;

  const SendCredexScreen({
    Key? key,
    required this.senderAccount,
    required this.accountRepository,
  }) : super(key: key);

  @override
  State<SendCredexScreen> createState() => _SendCredexScreenState();
}

class _SendCredexScreenState extends State<SendCredexScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  Denomination _selectedDenomination = Denomination.USD; // Default to USD
  bool _isLoading = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const ScanQRScreen(),
        fullscreenDialog: true, // This helps maintain proper navigation stack
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _recipientController.text = result;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final credexRequest = CredexRequest(
          issuerAccountID: widget.senderAccount.accountID,
          receiverAccountID: _recipientController.text,
          denomination: _selectedDenomination.toString().split('.').last,
          initialAmount: double.parse(_amountController.text),
          credexType: "PURCHASE", //TODO use the actual credex type
          offersOrRequests: "OFFERS",
          securedCredex: true,
        );
        
        final result = await widget.accountRepository.createCredex(credexRequest);
        
        result.fold(
          (failure) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${failure.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          },
          (response) {
            // Show success message and pop
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Credex sent successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          },
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(); // Ensure clean pop
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Send Credex'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sender account info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'From Account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.senderAccount.accountName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@${widget.senderAccount.accountHandle}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _recipientController,
                        decoration: const InputDecoration(
                          labelText: 'Recipient',
                          hintText: 'Enter recipient handle or scan QR code',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter recipient';
                          }
                          return null;
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: _scanQRCode,
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Scan QR Code',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: 'Enter amount to send',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<Denomination>(
                        value: _selectedDenomination,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                        items: Denomination.values.map((denomination) {
                          return DropdownMenuItem(
                            value: denomination,
                            child: Text(denomination.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (Denomination? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedDenomination = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
