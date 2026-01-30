import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/auth/resetpassword.dart';

class mailpassword extends StatefulWidget {
  const mailpassword({super.key});

  @override
  State<mailpassword> createState() => _mailpasswordState();
}

class _mailpasswordState extends State<mailpassword> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _validateAndSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      await Future.delayed(Duration(milliseconds: 500));

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => resetpassword()),
        ).then((_) {
          if (mounted) setState(() => _isLoading = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 50),
              Align(
                alignment: Alignment.center,
                child: Image.asset('image/mail.png'),
              ),
              SizedBox(height: 46),
              Text(
                'Check your email',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  text: "Kami mengirim 4 digit kode ke\n",
                  style: TextStyle(fontSize: 12),
                  children: [
                    TextSpan(
                      text: "smartcook@gmail.com",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _otpBox(context, true, false),
                    _otpBox(context, false, false),
                    _otpBox(context, false, false),
                    _otpBox(context, false, true),
                  ],
                ),
              ),
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: _isLoading ? null : _validateAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor().utama,
                  padding: EdgeInsets.symmetric(horizontal: 110, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        "Verify",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 25,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(BuildContext context, bool first, bool last) {
    return SizedBox(
      width: 70,
      height: 70,
      child: TextFormField(
        enabled: !_isLoading,
        onChanged: (value) {
          if (value.length == 1 && !last) {
            FocusScope.of(context).nextFocus();
          }
          if (value.isEmpty && !first) {
            FocusScope.of(context).previousFocus();
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "";
          }
          return null;
        },
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.normal),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 1,
        decoration: InputDecoration(
          counterText: "",
          errorStyle: TextStyle(height: 0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          fillColor: Color(0xFFD9D9D9),
          filled: true,
        ),
      ),
    );
  }
}
