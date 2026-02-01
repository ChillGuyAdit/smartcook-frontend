import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartcook/helper/color.dart';

class form extends StatefulWidget {
  const form({super.key});

  @override
  State<form> createState() => _formState();
}

class _formState extends State<form> {
  int _index = 0;

  String? usiaTerpilih;
  String? genderTerpilih;
  List<String> alergiTerpilih = [];
  List<String> riwayatPenyakitTerpilih = [];

  List<String> styleTerpilih = [];
  List<String> equipmentTerpilih = [];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidht = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: screenHeight * 0.08),
            child: Align(
              alignment: Alignment.topCenter,
              child: Image.asset(
                _index == 0
                    ? 'image/urutan1.png'
                    : _index == 1
                        ? 'image/urutan2.png'
                        : 'image/urutan3.png',
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                personalInformationWidget(screenWidht),
                addStyleWidget(screenWidht),
                addEquipmentWidget(screenWidht),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 35, vertical: 20),
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor().utama,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                padding: EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: () {
                setState(() {
                  if (_index < 2) {
                    _index++;
                  } else {
                    // Logic confirm
                  }
                });
              },
              child: Text(
                _index == 2 ? 'Confirm' : 'Lanjut',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColor().putih),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget personalInformationWidget(double sw) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(top: 20, bottom: 30),
        child: Column(
          children: [
            Image.asset('image/personalInformation.png'),
            Text('Personal Information', style: TextStyle(fontSize: 25)),
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 35),
              child: TextFormField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                  prefixIcon: Icon(Icons.person),
                  hintText: 'Masukkan Namamu...',
                  contentPadding: EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
            SizedBox(height: 15),
            labelForm(sw, 'Berapa Usiamu?'),
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                    padding: EdgeInsets.only(left: sw * 0.05),
                    child: itemUsia('< 12 thn')),
                itemUsia('12 - 17 thn'),
                Padding(
                    padding: EdgeInsets.only(right: sw * 0.05),
                    child: itemUsia('> 17 thn')),
              ],
            ),
            SizedBox(height: 14),
            labelForm(sw, 'Jenis kelamin'),
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                itemGender('Laki-laki', 'image/jenisKelaminCowo.png',
                    AppColor().IconGenCowo),
                itemGender('Perempuan', 'image/jenisKelaminCewe.png',
                    AppColor().iconGenCewe),
              ],
            ),
            SizedBox(height: 15),
            labelFormMulti(sw, 'Alergi Makanan ', '(Bisa Pilih Lebih > 1)'),
            SizedBox(height: 15),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Padding(
                        padding: EdgeInsets.only(left: sw * 0.05),
                        child: itemBoxFixed(alergiTerpilih, 'Kacang')),
                    itemBoxFixed(alergiTerpilih, 'Telur'),
                    Padding(
                        padding: EdgeInsets.only(right: sw * 0.05),
                        child: itemBoxFixed(alergiTerpilih, 'Susu')),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Padding(
                        padding: EdgeInsets.only(left: sw * 0.05),
                        child: itemBoxFixed(alergiTerpilih, 'Ikan')),
                    itemBoxFixed(alergiTerpilih, 'Seafod'),
                    Padding(
                        padding: EdgeInsets.only(right: sw * 0.05),
                        child: itemBoxFixed(alergiTerpilih, 'Kedelai')),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Padding(
                        padding: EdgeInsets.only(left: sw * 0.05),
                        child: itemBoxFixed(alergiTerpilih, 'Gandum')),
                    itemBoxFixed(alergiTerpilih, 'Susu Sapi'),
                    Padding(
                        padding: EdgeInsets.only(right: sw * 0.05),
                        child: itemBoxFixed(alergiTerpilih, 'Lainnya...')),
                  ],
                ),
              ],
            ),
            SizedBox(height: 15),
            labelForm(sw, 'Riwayat Penyakit'),
            SizedBox(height: 15),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  itemMulti(riwayatPenyakitTerpilih, 'Diabetes'),
                  itemMulti(riwayatPenyakitTerpilih, 'Kolesterol'),
                  itemMulti(riwayatPenyakitTerpilih, 'Asam Urat'),
                  itemMulti(riwayatPenyakitTerpilih, 'Hipertensi'),
                  itemMulti(riwayatPenyakitTerpilih, 'Maag / Gerd'),
                  itemMulti(riwayatPenyakitTerpilih, 'Obesitas'),
                  itemMulti(riwayatPenyakitTerpilih, 'Intoleransi Laktosa'),
                  itemMulti(riwayatPenyakitTerpilih, 'Gagal Ginjal'),
                  itemMulti(riwayatPenyakitTerpilih, 'Lainnya...'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget addStyleWidget(double sw) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: sw * 0.055),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 32),
            Text(
              'Apa Selera Masakanmu ?',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Pilih minimal 3 agar kami bisa kasih saran resep yang pas buat kamu',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 30),
            Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  itemGrid(styleTerpilih, 'Quick', 'image/style1.png', sw),
                  itemGrid(styleTerpilih, 'Healthy', 'image/style2.png', sw),
                  itemGrid(styleTerpilih, 'Budget', 'image/style3.png', sw),
                  itemGrid(styleTerpilih, 'Indo', 'image/style4.png', sw),
                  itemGrid(styleTerpilih, 'Western', 'image/style5.png', sw),
                  itemGrid(styleTerpilih, 'Chef', 'image/style6.png', sw),
                  itemGrid(styleTerpilih, 'Plant', 'image/style7.png', sw),
                  itemGrid(styleTerpilih, 'Balanced', 'image/style8.png', sw),
                ],
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget addEquipmentWidget(double sw) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: sw * 0.055),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 32),
            Text(
              'Lengkapi Senjatamu',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Beri tahu kami alat masakmu agar resep yang kami berikan bisa kamu buat',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 30),
            Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  itemGrid(equipmentTerpilih, 'Kompor', 'image/equip1.png', sw),
                  itemGrid(equipmentTerpilih, 'Oven', 'image/equip2.png', sw),
                  itemGrid(
                      equipmentTerpilih, 'Microwave', 'image/equip3.png', sw),
                  itemGrid(
                      equipmentTerpilih, 'Air Fryer', 'image/equip4.png', sw),
                  itemGrid(
                      equipmentTerpilih, 'Blender', 'image/equip5.png', sw),
                  itemGrid(equipmentTerpilih, 'Mixer', 'image/equip6.png', sw),
                  itemGrid(
                      equipmentTerpilih, 'Rice Cooker', 'image/equip7.png', sw),
                  itemGrid(
                      equipmentTerpilih, 'Toaster', 'image/equip8.png', sw),
                ],
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget itemGrid(
      List<String> list, String label, String imagePath, double sw) {
    bool isSelected = list.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          isSelected ? list.remove(label) : list.add(label);
        });
      },
      child: Stack(
        children: [
          Container(
            width: sw * 0.42,
            height: sw * 0.32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected ? AppColor().warnaIcon2 : Colors.transparent,
                width: 4,
              ),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColor().warnaIcon2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget labelForm(double sw, String text) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
          padding: EdgeInsets.only(left: sw * 0.09),
          child: Text(text, style: TextStyle(fontSize: 15))),
    );
  }

  Widget labelFormMulti(double sw, String t1, String t2) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(left: sw * 0.09),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 15, color: Colors.black),
            children: [
              TextSpan(text: t1),
              TextSpan(
                  text: t2, style: TextStyle(color: Colors.grey, fontSize: 12))
            ],
          ),
        ),
      ),
    );
  }

  Widget itemUsia(String label) {
    bool isSelected = usiaTerpilih == label;
    return GestureDetector(
      onTap: () => setState(() => usiaTerpilih = label),
      child: Container(
        width: 107,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? AppColor().utama : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColor().utama),
        ),
        child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 15,
                    color: isSelected ? Colors.white : Colors.black))),
      ),
    );
  }

  Widget itemGender(String gender, String imagePath, Color borderColor) {
    bool isSelected = genderTerpilih == gender;
    return GestureDetector(
      onTap: () => setState(() => genderTerpilih = gender),
      child: Container(
        height: 107,
        width: 164,
        decoration: BoxDecoration(
          color: isSelected ? borderColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? borderColor : borderColor.withOpacity(0.3),
              width: isSelected ? 3 : 1),
          image: DecorationImage(image: AssetImage(imagePath)),
        ),
      ),
    );
  }

  Widget itemBoxFixed(List<String> list, String label) {
    bool isSelected = list.contains(label);
    return GestureDetector(
      onTap: () =>
          setState(() => isSelected ? list.remove(label) : list.add(label)),
      child: Container(
        width: 107,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? AppColor().utama : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColor().utama),
        ),
        child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 15,
                    color: isSelected ? Colors.white : Colors.black))),
      ),
    );
  }

  Widget itemMulti(List<String> list, String label) {
    bool isSelected = list.contains(label);
    return GestureDetector(
      onTap: () =>
          setState(() => isSelected ? list.remove(label) : list.add(label)),
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: 10),
        constraints: BoxConstraints(minWidth: 107),
        decoration: BoxDecoration(
          color: isSelected ? AppColor().utama : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColor().utama),
        ),
        child: IntrinsicWidth(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      color: isSelected ? Colors.white : Colors.black)),
            ),
          ),
        ),
      ),
    );
  }
}
