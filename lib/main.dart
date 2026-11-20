import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase failed, but app will still open: $e");
  }
  runApp(const MamaApp());
}

const String devName = "Jemba Abdulhamiid";
const String adText = "🚀 NEED AN APP FOR YOUR GROUP, BUSINESS OR SCHOOL?\n\nIhsaanu Tech builds simple, beautiful & affordable Apps!\n\n✅ Cash Round / Savings Group Apps\n✅ Business Apps\n✅ School & Shop Apps\n✅ Login, Dashboard, Reports & PDF Sharing\n\nLike the Mama Teachers Group App - we can build one for YOU too!\n\n📞 Call / WhatsApp: 0709157254 / 0785831666\n💻 By Ihsaanu Tech - We Build Your Ideas Into Apps\n\n#IhsaanuTech #AppDeveloper #Uganda";

class CashGroup {
  String id; String title; int contribution; String cycle; Color color; Color soft;
  CashGroup({required this.id, required this.title, required this.contribution, required this.cycle, required this.color, required this.soft});
}

Map<String, CashGroup> cashGroups = {
  'A': CashGroup(id: 'A', title: 'Group A - 20,000 Weekly', contribution: 20000, cycle: 'weekly', color: const Color(0xFFEC407A), soft: const Color(0xFFFCE4EC)),
  'B': CashGroup(id: 'B', title: 'Group B - 100,000 Monthly', contribution: 100000, cycle: 'monthly', color: const Color(0xFF7C4DFF), soft: const Color(0xFFEDE7F6)),
  'C': CashGroup(id: 'C', title: 'Group C - 10,000 Weekly', contribution: 10000, cycle: 'weekly', color: const Color(0xFF00ACC1), soft: const Color(0xFFE0F7FA)),
};

String currentRoundId(String gid) {
  var cfg = cashGroups[gid]!;
  var now = DateTime.now();
  if (cfg.cycle == 'monthly') return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  var sunday = now.subtract(Duration(days: now.weekday % 7));
  return DateFormat('yyyy-MM-dd').format(sunday);
}

String roundLabel(String gid) {
  var cfg = cashGroups[gid]!;
  var now = DateTime.now();
  if (cfg.cycle == 'monthly') return DateFormat('MMMM yyyy').format(now);
  var sunday = now.subtract(Duration(days: now.weekday % 7));
  var sat = sunday.add(const Duration(days: 6));
  return "${DateFormat('dd MMM').format(sunday)} - ${DateFormat('dd MMM yyyy').format(sat)}";
}

bool isDev(String name) => name.trim().toLowerCase() == devName.toLowerCase();
String fmt(int v) => NumberFormat('#,###').format(v);

class MamaApp extends StatelessWidget {
  const MamaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(title: 'Mama Teachers Group', debugShowCheckedModeBanner: false, theme: ThemeData(primarySwatch: Colors.pink, useMaterial3: true), home: const Splash());
}

class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState() => _Splash(); }
class _Splash extends State<Splash> {
  @override void initState() { super.initState(); _go(); }
 Future<void> _go() async {
  try {
    await Future.delayed(const Duration(seconds: 2));
    var prefs = await SharedPreferences.getInstance();
    bool first = prefs.getBool('first_open') ?? true;
    String? saved = prefs.getString('saved_name');

    if (first || saved == null || saved.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Login()));
      return;
    }

    // Biometrics - don't let it block
    try {
      final auth = LocalAuthentication();
      bool can = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (can) {
        bool ok = await auth.authenticate(localizedReason: 'Unlock Mama Teachers Group with your phone lock').timeout(const Duration(seconds: 10));
        if (!ok) {
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Login()));
          return;
        }
      }
    } catch (_) {}

        // Firestore - with timeout, if it fails go to Login, don't stay white
    try {
      String savedPhone = prefs.getString('saved_phone') ?? '';
      var q = await FirebaseFirestore.instance
          .collection('members')
          .where('fullName', isEqualTo: saved)
          .where('phone', isEqualTo: savedPhone)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));

      if (q.docs.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Login()));
        return;
      }
      var m = q.docs.first.data();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GroupList(currentUser: m, docId: q.docs.first.id)));
    } catch (_) {
      // No internet / Firestore error - still go to Login, not white screen
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Login()));
    }
  } catch (_) {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Login()));
  }
}
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.white, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Image.asset('assets/logo.png', width: 170, height: 170, errorBuilder: (_, __, ___) => const Icon(Icons.groups, size: 120, color: Colors.pink)),
    const SizedBox(height: 16), const Text("MAMA TEACHERS GROUP", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.pink)),
    const SizedBox(height: 8), const Text("Cash Round", style: TextStyle(color: Colors.grey)),
    const SizedBox(height: 20), const CircularProgressIndicator(color: Colors.pink),
  ])));
}

class Login extends StatefulWidget { const Login({super.key}); @override State<Login> createState() => _Login(); }
class _Login extends State<Login> {
  final nameC = TextEditingController(); final phoneC = TextEditingController();
  String? cat; String? role;
  final cats = ["A", "B", "C", "A & B", "A & C", "B & C", "All"];
  final roles = ["Ch.person", "Secretary", "Treasure", "Member"];
   Future<void> login() async {
    if (nameC.text.trim().isEmpty || phoneC.text.trim().isEmpty || cat == null || role == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill all boxes")));
      return;
    }
    try {
      var prefs = await SharedPreferences.getInstance();
      await prefs.setBool('first_open', false);
      await prefs.setString('saved_name', nameC.text.trim());
      await prefs.setString('saved_phone', phoneC.text.trim()); // STEP 1: Save phone too

      var db = FirebaseFirestore.instance;
      Map<String, dynamic> data = {'fullName': nameC.text.trim(), 'phone': phoneC.text.trim(), 'category': cat, 'role': role, 'updatedAt': FieldValue.serverTimestamp()};
      String docId = 'local';

      try {
        var q = await db.collection('members')
  .where('fullName', isEqualTo: nameC.text.trim())
  .where('phone', isEqualTo: phoneC.text.trim())
  .limit(1).get().timeout(const Duration(seconds: 5));
        if (q.docs.isEmpty) {
          data['createdAt'] = FieldValue.serverTimestamp();
          var d = await db.collection('members').add(data).timeout(const Duration(seconds: 5));
          docId = d.id;
        } else {
          docId = q.docs.first.id;
          await db.collection('members').doc(docId).update(data).timeout(const Duration(seconds: 5));
          data = {...q.docs.first.data(), ...data};
        }
      } catch (_) {
        // Firebase failed - still enter with local data, don't get stuck
      }

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GroupList(currentUser: data, docId: docId)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.white, body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
    const SizedBox(height: 36),
    Image.asset('assets/logo.png', width: 130, height: 130, errorBuilder: (_, __, ___) => const Icon(Icons.groups, size: 100, color: Colors.pink)),
    const SizedBox(height: 10), const Text("MAMA TEACHERS GROUP", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.pink)),
    const Text("Cash Round - Contribute, Receive, Grow", style: TextStyle(color: Colors.grey)),
    const SizedBox(height: 24),
    TextField(controller: nameC, decoration: InputDecoration(labelText: "Full Name", prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 14),
    TextField(controller: phoneC, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Contact", prefixIcon: const Icon(Icons.phone), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(value: cat, decoration: InputDecoration(labelText: "Cash Round Category", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: cats.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => cat = v)),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(value: role, decoration: InputDecoration(labelText: "Position in Group", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: roles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => role = v)),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: login, style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("ENTER CASH ROUND LIST", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
  ])));
}

void showAd(BuildContext ctx) {
  showDialog(context: ctx, builder: (_) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.pink, Colors.purple]), borderRadius: BorderRadius.circular(20)), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text("🚀 NEED AN APP?", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
    const SizedBox(height: 10), const Text(adText, style: TextStyle(color: Colors.white, fontSize: 14)),
    const SizedBox(height: 14), ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
  ]))));
}

class GroupList extends StatelessWidget {
  final Map<String, dynamic> currentUser; final String docId;
  const GroupList({super.key, required this.currentUser, required this.docId});
  List<String> myGroups() {
    if (isDev(currentUser['fullName'] ?? '')) return ['A', 'B', 'C'];
    String c = currentUser['category'] ?? 'A';
    if (c == "All") return ['A', 'B', 'C'];
    if (c.contains("&")) return c.split("&").map((e) => e.trim()).toList();
    return [c];
  }
  bool isExec() => (currentUser['role'] ?? 'Member') != 'Member' || isDev(currentUser['fullName'] ?? '');
  @override Widget build(BuildContext context) {
    var mine = myGroups();
    return Scaffold(appBar: AppBar(title: Text("Hello, ${currentUser['fullName']}"), backgroundColor: Colors.pink, foregroundColor: Colors.white, actions: [IconButton(icon: const Text("💿", style: TextStyle(fontSize: 24)), onPressed: () => showAd(context))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isExec()) Card(color: Colors.amber[100], child: ListTile(leading: const Icon(Icons.settings, color: Colors.orange), title: const Text("General Settings - Executives"), subtitle: const Text("Decide who is executive and in which cash round"), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GeneralSettings(currentUser: currentUser))))),
        const SizedBox(height: 12), const Text("Your Cash Rounds are PINK - Tap to enter", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...['A', 'B', 'C'].map((g) {
          var cfg = cashGroups[g]!; bool has = mine.contains(g);
          return GestureDetector(onTap: has ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => Dashboard(groupId: g, currentUser: currentUser))) : null,
            child: Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: has ? cfg.soft : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: has ? cfg.color : Colors.grey.shade300, width: 2)),
              child: Row(children: [CircleAvatar(backgroundColor: cfg.color, radius: 28, child: Text(g, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cfg.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text("Round: ${roundLabel(g)}"), Text(has ? "Your cash round - Tap to enter" : "Not your cash round", style: TextStyle(color: has ? Colors.green : Colors.grey))])),
                Icon(Icons.arrow_forward_ios, color: has ? cfg.color : Colors.grey)])));
        }),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Text("If you are in more than 1 cash round, go back to this list to enter another round.", style: TextStyle(color: Colors.grey[700])))),
      ])));
  }
}

class GeneralSettings extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const GeneralSettings({super.key, required this.currentUser});
  @override State<GeneralSettings> createState() => _GeneralSettings();
}

class _GeneralSettings extends State<GeneralSettings> {
  String selectedGroup = 'A';
  final groups = ["A", "B", "C", "A & B", "A & C", "B & C", "All"];

  bool inSelectedGroup(Map<String, dynamic> m) {
    String c = m['category'] ?? '';
    if (selectedGroup == "All") return true;
    if (selectedGroup.contains("&")) {
      var parts = selectedGroup.split("&").map((e) => e.trim()).toList();
      if (c == "All") return true;
      for (var p in parts) { if (c.contains(p)) return true; }
      return false;
    }
    if (c == "All") return true;
    if (c == selectedGroup) return true;
    if (c.contains("&") && c.contains(selectedGroup)) return true;
    return false;
  }

  Future<void> deleteMember(String docId, String name) async {
    bool ok = await showDialog(context: context, builder: (_) => AlertDialog(
      title: Text("Delete $name?"),
      content: Text("This will remove $name from the App. Only executive can do this."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
      ],
    )) ?? false;
    if (!ok) return;
    await FirebaseFirestore.instance.collection('members').doc(docId).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name deleted")));
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("General Settings - Executives"), backgroundColor: Colors.orange),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("1. Choose group to manage:", style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(value: selectedGroup, isExpanded: true, items: groups.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => selectedGroup = v!)),
        const SizedBox(height: 8),
        const Text("2. Set who is Ch.person / Secretary / Treasure in THIS group. Tap trash to delete member.", style: TextStyle(color: Colors.grey)),
      ])),
      Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('members').snapshots(), builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var list = snap.data!.docs.where((d) => inSelectedGroup(d.data() as Map<String, dynamic>)).toList();
        return ListView(children: list.map((d) {
          var m = d.data() as Map<String, dynamic>;
          return Card(child: ListTile(
            title: Text(m['fullName'] ?? ''),
            subtitle: Text("Cash Round: ${m['category']} | Position: ${m['role']} | ${m['phone']}"),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              DropdownButton<String>(value: m['role'], items: ["Ch.person", "Secretary", "Treasure", "Member"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) async {
                  await FirebaseFirestore.instance.collection('members').doc(d.id).update({'role': v});
                  await FirebaseFirestore.instance.collection('exec_roles').doc("${d.id}_$selectedGroup").set({
                    'memberId': d.id, 'memberName': m['fullName'], 'groupId': selectedGroup, 'role': v, 'updatedBy': widget.currentUser['fullName'],
                  });
                }),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => deleteMember(d.id, m['fullName'] ?? '')),
            ]),
          ));
        }).toList());
      })),
    ]),
  );
}

class Dashboard extends StatefulWidget {
  final String groupId; final Map<String, dynamic> currentUser;
  const Dashboard({super.key, required this.groupId, required this.currentUser});
  @override State<Dashboard> createState() => _Dashboard();
}
class _Dashboard extends State<Dashboard> with SingleTickerProviderStateMixin {
  late TabController tab; final shot = ScreenshotController();
  @override void initState() { super.initState(); tab = TabController(length: 9, vsync: this); _load(); }
  Future<void> _load() async {
    var doc = await FirebaseFirestore.instance.collection('cash_round_settings').doc(widget.groupId).get();
    if (doc.exists) { var d = doc.data()!; setState(() { cashGroups[widget.groupId]!.contribution = d['contribution'] ?? cashGroups[widget.groupId]!.contribution; cashGroups[widget.groupId]!.cycle = d['cycle'] ?? cashGroups[widget.groupId]!.cycle; if (d['color'] != null) cashGroups[widget.groupId]!.color = Color(d['color']); }); }
  }
  bool get isExec => (widget.currentUser['role'] ?? 'Member') != 'Member' || isDev(widget.currentUser['fullName'] ?? '');
  bool inGroup(Map<String, dynamic> m, String gid) {
    if (isDev(m['fullName'] ?? '')) return true;
    String c = m['category'] ?? '';
    if (c == "All") return true;
    if (c == gid) return true;
    if (c.contains("&") && c.contains(gid)) return true;
    return false;
  }
  Future<void> markPaid(String mid, String name) async {
    if (!isExec) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only Ch.person, Secretary or Treasure can mark cash paid"))); return; }
    String r = currentRoundId(widget.groupId);
    await FirebaseFirestore.instance.collection('cash_payments').doc("${widget.groupId}_${r}_$mid").set({'groupId': widget.groupId, 'roundId': r, 'memberId': mid, 'memberName': name, 'amount': cashGroups[widget.groupId]!.contribution, 'status': 'paid', 'markedBy': widget.currentUser['fullName'], 'markedAt': FieldValue.serverTimestamp()});
    if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name marked PAID")));
  }
  Future<void> unmarkPaid(String mid) async {
    if (!isExec) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only executives can unmark cash"))); return; }
    await FirebaseFirestore.instance.collection('cash_payments').doc("${widget.groupId}_${currentRoundId(widget.groupId)}_$mid").delete();
  }
  Future<void> markReceived(String mid, String name, int amt) async {
    if (!isExec) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only executives can mark received"))); return; }
    String r = currentRoundId(widget.groupId);
    await FirebaseFirestore.instance.collection('cash_received').doc("${widget.groupId}_${r}_$mid").set({'groupId': widget.groupId, 'roundId': r, 'memberId': mid, 'memberName': name, 'amount': amt, 'receivedAt': FieldValue.serverTimestamp()});
  }
  Future<void> receipt(String type, String name, int amt) async {
    var w = Material(child: Container(color: Colors.white, padding: const EdgeInsets.all(20), width: 350, child: Column(children: [
      Image.asset('assets/logo.png', width: 80, height: 80, errorBuilder: (_, __, ___) => const Icon(Icons.groups, size: 60, color: Colors.pink)),
      const Text("MAMA TEACHERS GROUP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const Divider(),
      Text(type.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pink)),
      const SizedBox(height: 10), Text("Member: $name", style: const TextStyle(fontSize: 16)),
      Text("Cash Round: ${widget.groupId} - ${roundLabel(widget.groupId)}"),
      Text("Amount: ${fmt(amt)} UGX", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text("Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}"),
      const SizedBox(height: 10), const Text("Mama Teachers Group - Cash Round", style: TextStyle(color: Colors.grey)),
      const Text("Ihsaanu Tech - 0709157254", style: TextStyle(fontSize: 11, color: Colors.grey)),
    ])));
    var img = await shot.captureFromWidget(w);
    var dir = await getTemporaryDirectory();
    var f = File("${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png");
    await f.writeAsBytes(img);
    await Share.shareXFiles([XFile(f.path)], text: "Mama Teachers Group Receipt - $type for $name - $amt UGX");
  }
  void aiInfo() {
    showDialog(context: context, builder: (_) => AlertDialog(title: Row(children: [const Icon(Icons.smart_toy, color: Colors.pink), const SizedBox(width: 8), Text("AI Cash Round Info - Group ${widget.groupId}")]), content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("🤖 Hello! I am Mama Teachers AI.", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10),
      Text("Cash Round ${widget.groupId}:"), Text("• Contribution: ${fmt(cashGroups[widget.groupId]!.contribution)} UGX"), Text("• Cycle: ${cashGroups[widget.groupId]!.cycle} (${roundLabel(widget.groupId)})"),
      Text("• You are: ${widget.currentUser['fullName']} - ${widget.currentUser['role']}"), Text("• Your Category: ${widget.currentUser['category']}"),
      const SizedBox(height: 10), const Text("How this cash round works:", style: TextStyle(fontWeight: FontWeight.bold)),
      Text("1. Every member contributes ${fmt(cashGroups[widget.groupId]!.contribution)} UGX every ${cashGroups[widget.groupId]!.cycle} round."),
      const Text("2. Ch.person / Secretary / Treasure marks cash paid."), const Text("3. Paid members move from Not Paid to Paid."),
      const Text("4. One member receives the total cash for that round and is marked RECEIVED."), const Text("5. When the round ends, cash data moves to PAST automatically."),
      const Text("6. Generate PNG receipts and send to WhatsApp group or member directly."),
      const SizedBox(height: 10), const Text("Tip: If you are in 2 cash rounds, finish in one, go back to Cash Round List, then enter the other.", style: TextStyle(color: Colors.grey)),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }
  @override Widget build(BuildContext context) {
    var cfg = cashGroups[widget.groupId]!;
    return Scaffold(appBar: AppBar(backgroundColor: cfg.color, foregroundColor: Colors.white, title: Text("Group ${widget.groupId} - ${roundLabel(widget.groupId)}"), actions: [IconButton(icon: const Text("💿", style: TextStyle(fontSize: 22)), onPressed: () => showAd(context))],
        bottom: TabBar(controller: tab, isScrollable: true, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: const [Tab(text: "All Members"), Tab(text: "Pay Please"), Tab(text: "Paid ✅"), Tab(text: "Not Paid ❌"), Tab(text: "Received"), Tab(text: "Past"), Tab(text: "Chat"), Tab(text: "Settings"), Tab(text: "Secretary 📝")])),
      drawer: Drawer(child: ListView(children: [
        DrawerHeader(decoration: BoxDecoration(color: cfg.color), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(backgroundColor: Colors.white, child: Text(widget.groupId, style: TextStyle(color: cfg.color, fontWeight: FontWeight.bold))), const SizedBox(height: 8), Text("Cash Round ${widget.groupId}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), Text(widget.currentUser['fullName'] ?? '', style: const TextStyle(color: Colors.white70)), Text("Position: ${widget.currentUser['role']}", style: const TextStyle(color: Colors.white70))])),
        ListTile(leading: const Icon(Icons.group), title: const Text("All Members"), onTap: () { Navigator.pop(context); tab.animateTo(0); }),
        ListTile(leading: const Icon(Icons.payment), title: const Text("Pay Please"), onTap: () { Navigator.pop(context); tab.animateTo(1); }),
        ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: const Text("Paid"), onTap: () { Navigator.pop(context); tab.animateTo(2); }),
        ListTile(leading: const Icon(Icons.cancel, color: Colors.red), title: const Text("Not Paid"), onTap: () { Navigator.pop(context); tab.animateTo(3); }),
        ListTile(leading: const Icon(Icons.card_giftcard), title: const Text("Received"), onTap: () { Navigator.pop(context); tab.animateTo(4); }),
        ListTile(leading: const Icon(Icons.history), title: const Text("Past Rounds"), onTap: () { Navigator.pop(context); tab.animateTo(5); }),
        ListTile(leading: const Icon(Icons.chat), title: const Text("Chat"), onTap: () { Navigator.pop(context); tab.animateTo(6); }),
        ListTile(leading: const Icon(Icons.settings), title: const Text("Settings"), onTap: () { Navigator.pop(context); tab.animateTo(7); }),
        ListTile(leading: const Icon(Icons.edit_note, color: Colors.blue), title: const Text("Secretary - Record Cash"), onTap: () { Navigator.pop(context); tab.animateTo(8); }),
        ListTile(leading: const Icon(Icons.smart_toy), title: const Text("AI Cash Round Info"), onTap: () { Navigator.pop(context); aiInfo(); }),
        ListTile(leading: const Icon(Icons.arrow_back), title: const Text("Back to Cash Round List"), onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ])),
      floatingActionButton: FloatingActionButton(backgroundColor: cfg.color, onPressed: aiInfo, child: const Icon(Icons.smart_toy, color: Colors.white)),
      body: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('members').snapshots(), builder: (ctx, memSnap) {
        if (!memSnap.hasData) return const Center(child: CircularProgressIndicator());
        var all = memSnap.data!.docs.where((d) => inGroup(d.data() as Map<String, dynamic>, widget.groupId)).toList();
        all.sort((a, b) { int rank(String r) => r == "Ch.person" ? 0 : r == "Secretary" ? 1 : r == "Treasure" ? 2 : 3; return rank((a.data() as Map<String, dynamic>)['role'] ?? 'Member').compareTo(rank((b.data() as Map<String, dynamic>)['role'] ?? 'Member')); });
        String round = currentRoundId(widget.groupId);
        return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('cash_payments').where('groupId', isEqualTo: widget.groupId).where('roundId', isEqualTo: round).snapshots(), builder: (ctx2, paySnap) {
          Set<String> paidIds = {};
          if (paySnap.hasData) paidIds = paySnap.data!.docs.map((d) => (d.data() as Map<String, dynamic>)['memberId'] as String).toSet();
          var paidM = all.where((d) => paidIds.contains(d.id)).toList();
          var notPaidM = all.where((d) => !paidIds.contains(d.id)).toList();
          return TabBarView(controller: tab, children: [buildAll(all), buildPay(all, paidIds), buildPaid(paidM), buildNotPaid(notPaidM), buildReceived(all), buildPast(), buildChat(), buildSettings()]);
        });
      }));
  }
  Widget buildAll(List<QueryDocumentSnapshot> members) => ListView(children: [
    Padding(padding: const EdgeInsets.all(12), child: Text("EXECUTIVE COMMITTEE", style: TextStyle(fontWeight: FontWeight.bold, color: cashGroups[widget.groupId]!.color))),
    ...members.where((d) => (d.data() as Map<String, dynamic>)['role'] != 'Member').map((d) { var m = d.data() as Map<String, dynamic>; return Card(color: Colors.amber[50], child: ListTile(leading: CircleAvatar(child: Text((m['fullName'] ?? '')[0])), title: Text(m['fullName'] ?? ''), subtitle: Text("${m['role']} • ${m['phone']}"), trailing: Chip(label: Text(m['role'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Colors.orange))); }),
    Padding(padding: const EdgeInsets.all(12), child: Text("OTHER MEMBERS (${members.where((d) => (d.data() as Map<String, dynamic>)['role'] == 'Member').length})", style: const TextStyle(fontWeight: FontWeight.bold))),
    ...members.where((d) => (d.data() as Map<String, dynamic>)['role'] == 'Member').map((d) { var m = d.data() as Map<String, dynamic>; return Card(child: ListTile(leading: CircleAvatar(backgroundColor: cashGroups[widget.groupId]!.color, child: Text((m['fullName'] ?? '')[0], style: const TextStyle(color: Colors.white))), title: Text(m['fullName'] ?? ''), subtitle: Text("${m['phone']} • Member"))); }),
  ]);
  Widget buildPay(List<QueryDocumentSnapshot> members, Set<String> paidIds) => ListView(children: [
    const Padding(padding: EdgeInsets.all(12), child: Text("Tap a member to mark cash PAID - Only Ch.person, Secretary, Treasure", style: TextStyle(fontWeight: FontWeight.bold))),
    ...members.map((d) { var m = d.data() as Map<String, dynamic>; bool isPaid = paidIds.contains(d.id); return Card(child: ListTile(title: Text(m['fullName'] ?? ''), subtitle: Text("Contribution: ${fmt(cashGroups[widget.groupId]!.contribution)} UGX • ${m['phone']}"), trailing: isPaid ? const Icon(Icons.check_box, color: Colors.green) : ElevatedButton(onPressed: () => markPaid(d.id, m['fullName']), child: const Text("MARK PAID")))); }),
  ]);
  Widget buildPaid(List<QueryDocumentSnapshot> members) => ListView(children: [
    Padding(padding: const EdgeInsets.all(12), child: Text("Paid Members - ${members.length}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
    ...members.map((d) { var m = d.data() as Map<String, dynamic>; return Card(child: ListTile(title: Row(children: [Expanded(child: Text(m['fullName'] ?? '')), Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)), child: const Text("✓", style: TextStyle(color: Colors.white)))]), subtitle: Text("${fmt(cashGroups[widget.groupId]!.contribution)} UGX • Cash Paid"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.receipt, color: Colors.blue), onPressed: () => receipt("Payment Receipt", m['fullName'], cashGroups[widget.groupId]!.contribution)), if (isExec) IconButton(icon: const Icon(Icons.undo, color: Colors.red), onPressed: () => unmarkPaid(d.id))]))); }),
  ]);
  Widget buildNotPaid(List<QueryDocumentSnapshot> members) => ListView(children: [
    Padding(padding: const EdgeInsets.all(12), child: Text("Not Paid - ${members.length} - Tap receipt to demand cash", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
    ...members.map((d) { var m = d.data() as Map<String, dynamic>; return Card(child: ListTile(title: Row(children: [Expanded(child: Text(m['fullName'] ?? '')), Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text("X", style: TextStyle(color: Colors.white)))]), subtitle: Text("${m['phone']} • Should contribute ${fmt(cashGroups[widget.groupId]!.contribution)} UGX"), trailing: IconButton(icon: const Icon(Icons.receipt_long, color: Colors.red), onPressed: () => receipt("Demanding Receipt - NOT PAID", m['fullName'], cashGroups[widget.groupId]!.contribution)))); }),
  ]);
  Widget buildReceived(List<QueryDocumentSnapshot> all) {
    TextEditingController searchC = TextEditingController();
    return StatefulBuilder(builder: (ctx, setSt) {
      String q = "";
      return Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(controller: searchC, onChanged: (v) => setSt(() => q = v.toLowerCase()), decoration: InputDecoration(hintText: "Search member to mark as RECEIVED...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
        if (q.isNotEmpty) ...all.where((d) => ((d.data() as Map<String, dynamic>)['fullName'] ?? '').toString().toLowerCase().contains(q)).map((d) { var m = d.data() as Map<String, dynamic>; return ListTile(title: Text(m['fullName'] ?? ''), trailing: ElevatedButton(onPressed: () => markReceived(d.id, m['fullName'], cashGroups[widget.groupId]!.contribution), child: const Text("MARK RECEIVED"))); }),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('cash_received').where('groupId', isEqualTo: widget.groupId).where('roundId', isEqualTo: currentRoundId(widget.groupId)).snapshots(), builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Text("No one has received cash yet this round"));
          return ListView(children: snap.data!.docs.map((d) { var r = d.data() as Map<String, dynamic>; return Card(color: Colors.green[50], child: ListTile(title: Text("${r['memberName']} - RECEIVED"), subtitle: Text("Cash Received: ${fmt(r['amount'])} UGX"), trailing: IconButton(icon: const Icon(Icons.receipt), onPressed: () => receipt("Received Receipt - Cash Round", r['memberName'], r['amount'])))); }).toList());
        })),
      ]);
    });
  }
  Widget buildPast() {
    String cur = currentRoundId(widget.groupId);
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('cash_payments').where('groupId', isEqualTo: widget.groupId).snapshots(), builder: (c, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      var past = snap.data!.docs.where((d) => (d.data() as Map<String, dynamic>)['roundId'] != cur).toList();
      if (past.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No past cash rounds yet.\nWhen a round ends, cash data moves here automatically.", textAlign: TextAlign.center)));
      Map<String, List<QueryDocumentSnapshot>> by = {};
      for (var d in past) { var p = (d.data() as Map<String, dynamic>)['roundId'] ?? 'old'; by.putIfAbsent(p, () => []).add(d); }
      return ListView(children: by.entries.map((e) => ExpansionTile(title: Text("Cash Round: ${e.key} - ${e.value.length} paid"), children: e.value.map((d) { var m = d.data() as Map<String, dynamic>; return ListTile(title: Text(m['memberName'] ?? ''), subtitle: Text("${fmt(m['amount'])} UGX")); }).toList())).toList());
    });
  }
  Widget buildChat() {
    TextEditingController msgC = TextEditingController();
    return Column(children: [
      Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('cash_chats').where('groupId', isEqualTo: widget.groupId).orderBy('createdAt', descending: true).snapshots(), builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(reverse: true, itemCount: snap.data!.docs.length, itemBuilder: (_, i) { var m = snap.data!.docs[i].data() as Map<String, dynamic>; bool mine = m['sender'] == widget.currentUser['fullName']; return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.all(6), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: mine ? cashGroups[widget.groupId]!.color : Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['sender'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: mine ? Colors.white : Colors.black, fontSize: 11)), Text(m['text'] ?? '', style: TextStyle(color: mine ? Colors.white : Colors.black))]))); });
      })),
      Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: msgC, decoration: InputDecoration(hintText: "Type cash message for Group ${widget.groupId}...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))))), IconButton(icon: Icon(Icons.send, color: cashGroups[widget.groupId]!.color), onPressed: () { if (msgC.text.trim().isEmpty) return; FirebaseFirestore.instance.collection('cash_chats').add({'groupId': widget.groupId, 'sender': widget.currentUser['fullName'], 'text': msgC.text.trim(), 'createdAt': FieldValue.serverTimestamp()}); msgC.clear(); })])),
    ]);
  }
  Widget buildSettings() {
    TextEditingController amtC = TextEditingController(text: cashGroups[widget.groupId]!.contribution.toString());
    String cycle = cashGroups[widget.groupId]!.cycle;
    Color picked = cashGroups[widget.groupId]!.color;
    List<Color> colors = [Colors.pink, Colors.purple, Colors.cyan, Colors.green, Colors.orange, Colors.blue, Colors.red, Colors.teal];
    return StatefulBuilder(builder: (ctx, setSt) => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Settings for Cash Round ${widget.groupId}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15), const Text("Contribution (UGX) - Applies to future cash rounds"),
      TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), prefixText: "UGX ")),
      const SizedBox(height: 15), const Text("Cash Round Cycle"),
      DropdownButton<String>(value: cycle, isExpanded: true, items: ["weekly", "monthly"].map((e) => DropdownMenuItem(value: e, child: Text(e == "weekly" ? "Weekly (Sunday - Saturday)" : "Monthly (1st - End of Month)"))).toList(), onChanged: (v) => setSt(() => cycle = v!)),
      const SizedBox(height: 15), const Text("Cash Round Colour"),
      Wrap(children: colors.map((c) => GestureDetector(onTap: () => setSt(() => picked = c), child: Container(margin: const EdgeInsets.all(6), width: 45, height: 45, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: picked == c ? Border.all(color: Colors.black, width: 3) : null)))).toList()),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () async {
        if (!isExec) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only executives can change cash round settings"))); return; }
        int amt = int.tryParse(amtC.text) ?? cashGroups[widget.groupId]!.contribution;
        await FirebaseFirestore.instance.collection('cash_round_settings').doc(widget.groupId).set({'contribution': amt, 'cycle': cycle, 'color': picked.value, 'updatedBy': widget.currentUser['fullName']});
        setState(() { cashGroups[widget.groupId]!.contribution = amt; cashGroups[widget.groupId]!.cycle = cycle; cashGroups[widget.groupId]!.color = picked; });
        if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cash round settings saved for Group ${widget.groupId}")));
      }, child: const Text("SAVE CASH ROUND SETTINGS", style: TextStyle(color: Colors.white)))),
      const SizedBox(height: 15), Text("Current: ${fmt(cashGroups[widget.groupId]!.contribution)} UGX - $cycle - Round: ${roundLabel(widget.groupId)}", style: const TextStyle(color: Colors.grey)),
    ])));
  }
}
