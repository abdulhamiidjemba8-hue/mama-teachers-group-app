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

import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase failed, but app will still open: $e");
  }

  // STEP 7: Ask for notification permission
  try {
    FirebaseMessaging msg = FirebaseMessaging.instance;
    await msg.requestPermission(alert: true, badge: true, sound: true);
    // Show notification even when app is open
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
  } catch (_) {}

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

// STEP 8 - PLAN B: No Server Key needed
Future<void> sendPushToGroup(String gid, String title, String body, String senderName) async {
  try {
    await FirebaseFirestore.instance.collection('notifications').add({
      'groupId': gid,
      'title': title,
      'body': body,
      'sender': senderName,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [senderName],
    });
  } catch (e) {
    print("Notify error: $e");
  }
}

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
  final roles = ["Ch.person", "Member"];
     // Helper: Turn "A & B" / "All" into list ["A","B"]
  List<String> groupsFromCat(String c) {
    if (c == "All") return ['A', 'B', 'C'];
    if (c.contains("&")) return c.split("&").map((e) => e.trim()).toList();
    return [c];
  }

  Future<void> login() async {
    if (nameC.text.trim().isEmpty || phoneC.text.trim().isEmpty || cat == null || role == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill all boxes")));
      return;
    }

    // 1. CHECK - Only Ch.person is checked at login. Secretary/Treasure are set later by Ch.person
if (role == 'Ch.person') {
      var myGroups = groupsFromCat(cat!);
      for (String g in myGroups) {
        var existing = await FirebaseFirestore.instance
            .collection('exec_roles')
            .where('groupId', isEqualTo: g)
            .where('role', isEqualTo: role)
            .get();

        // If someone else already has it - BLOCK
        // We don't know our docId yet, so check by name - if holder name != my name, block
        var others = existing.docs.where((doc) {
          var e = doc.data() as Map<String, dynamic>;
          return (e['memberName'] ?? '').toString().trim().toLowerCase() != nameC.text.trim().toLowerCase();
        }).toList();

        if (others.isNotEmpty) {
          var holder = others.first.data() as Map<String, dynamic>;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ ${holder['memberName']} is already $role in Group $g. Pick Member or another group."),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          return; // STOP - Don't login as executive
        }
      }
    }

    try {
      var prefs = await SharedPreferences.getInstance();
      await prefs.setBool('first_open', false);
      await prefs.setString('saved_name', nameC.text.trim());
      await prefs.setString('saved_phone', phoneC.text.trim());

      var db = FirebaseFirestore.instance;
      String fcmToken = '';
      try {
        fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
      } catch (_) {}

      // 2. FIX - Use the role user PICKED, not always 'Member'
      Map<String, dynamic> data = {
        'fullName': nameC.text.trim(),
        'phone': phoneC.text.trim(),
        'category': cat,
        'role': role, // ✅ Now uses picked role
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp()
      };
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

       // 3. SAVE ROLE TO exec_roles - ONLY Ch.person at login
// If Member: DO NOT delete exec_roles! He may be Ch.person in A, Member in B
if (role == 'Ch.person') {
  var myGroups = groupsFromCat(cat!);
  for (String g in myGroups) {
    await db.collection('exec_roles').doc("${docId}_$g").set({
      'memberId': docId,
      'memberName': nameC.text.trim(),
      'groupId': g,
      'role': 'Ch.person',
      'updatedBy': nameC.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
// Member login: create nothing. Ch.person will promote him later in General Settings.
      } catch (_) {
        // Firebase failed - still enter with local data
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
  // FIX 1: Only single groups. No "A & B", no "All" — that's what caused confusion
  String selectedGroup = 'A';
  final groups = ["A", "B", "C"];
  final roles = ["Ch.person", "Secretary", "Treasure", "Member"];

  // Which person is selected for long-press delete
  String? selectedForDeleteId;

  bool inSelectedGroup(Map<String, dynamic> m) {
    String c = m['category'] ?? '';
    if (c == "All") return true;
    if (c == selectedGroup) return true;
    if (c.contains("&") && c.contains(selectedGroup)) return true;
    return false;
  }

  // FIX 2: Get role FOR THIS GROUP ONLY from exec_roles
  String roleForGroup(String memberId, Map<String, dynamic> execMap) {
    return execMap["${memberId}_$selectedGroup"] ?? "Member";
  }

  Future<void> deleteMember(String docId, String name) async {
    bool ok = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete $name?"),
        content: Text("This will remove $name from the App completely. Only executive can do this."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    await FirebaseFirestore.instance.collection('members').doc(docId).delete();
    // Also clean exec roles for this person
    var execs = await FirebaseFirestore.instance.collection('exec_roles').where('memberId', isEqualTo: docId).get();
    for (var d in execs.docs) { await d.reference.delete(); }
    if (!mounted) return;
    setState(() => selectedForDeleteId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name deleted")));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("General Settings - Executives"), backgroundColor: Colors.orange),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("1. Choose group to manage:", style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: selectedGroup,
            isExpanded: true,
            items: groups.map((e) => DropdownMenuItem(value: e, child: Text("Group $e"))).toList(),
            onChanged: (v) => setState(() {
              selectedGroup = v!;
              selectedForDeleteId = null; // clear delete selection when group changes
            }),
          ),
          const SizedBox(height: 8),
          // FIX 3: MAKE IT CLEAR - Big banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange)),
            child: Text(
              "You are now managing ONLY Group $selectedGroup\nChanges here will NOT affect Group ${selectedGroup == 'A' ? 'B or C' : selectedGroup == 'B' ? 'A or C' : 'A or B'}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          const Text("2. Long-press a person to show DELETE. Use dropdown to set position in THIS group only.", style: TextStyle(color: Colors.grey)),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('exec_roles').snapshots(),
          builder: (ctxExec, execSnap) {
            // Build map: "memberId_Group" -> role
            Map<String, dynamic> execMap = {};
            if (execSnap.hasData) {
              for (var d in execSnap.data!.docs) {
                var e = d.data() as Map<String, dynamic>;
                execMap["${e['memberId']}_${e['groupId']}"] = e['role'];
              }
            }
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('members').snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                var list = snap.data!.docs.where((d) => inSelectedGroup(d.data() as Map<String, dynamic>)).toList();
                return ListView(children: list.map((d) {
                  var m = d.data() as Map<String, dynamic>;
                  // FIX 4: Read role for THIS group only
                  String roleHere = roleForGroup(d.id, execMap);
                  bool showDelete = selectedForDeleteId == d.id;
                  return GestureDetector(
                    // FIX 5: LONG PRESS TO DELETE
                    onLongPress: () => setState(() => selectedForDeleteId = d.id),
                    onTap: () {
                      if (showDelete) setState(() => selectedForDeleteId = null);
                    },
                    child: Card(
                      color: showDelete ? Colors.red.shade50 : null,
                      child: ListTile(
                        title: Text(m['fullName'] ?? ''),
                        subtitle: Text("Cash Round: ${m['category']} | Position in Group $selectedGroup: $roleHere | ${m['phone']}"),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          DropdownButton<String>(
                            value: roles.contains(roleHere) ? roleHere : "Member",
                            items: roles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                                       onChanged: (v) async {
                              if (v == null) return;

                              // 1. Member is always allowed - no limit
                              if (v == 'Member') {
                                await FirebaseFirestore.instance.collection('exec_roles').doc("${d.id}_$selectedGroup").set({
                                  'memberId': d.id,
                                  'memberName': m['fullName'],
                                  'groupId': selectedGroup,
                                  'role': 'Member',
                                  'updatedBy': widget.currentUser['fullName'],
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                                return;
                              }

                              // 2. CHECK: Does someone else already have this role in THIS group?
                              var existing = await FirebaseFirestore.instance
                                  .collection('exec_roles')
                                  .where('groupId', isEqualTo: selectedGroup)
                                  .where('role', isEqualTo: v)
                                  .get();

                              var others = existing.docs.where((doc) => (doc.data() as Map<String, dynamic>)['memberId'] != d.id).toList();

                              // 3. BLOCK if second one
                              if (others.isNotEmpty) {
                                var holder = others.first.data() as Map<String, dynamic>;
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("❌ ${holder['memberName']} is already $v in Group $selectedGroup. Delete them or change them to Member first."),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                return;
                              }

                              // 4. No one else has it - Allow
                              await FirebaseFirestore.instance.collection('exec_roles').doc("${d.id}_$selectedGroup").set({
                                'memberId': d.id,
                                'memberName': m['fullName'],
                                'groupId': selectedGroup,
                                'role': v,
                                'updatedBy': widget.currentUser['fullName'],
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("${m['fullName']} is now $v in Group $selectedGroup ONLY")),
                              );
                            },
                          ),
                          // Delete icon appears ONLY after long-press
                          if (showDelete)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteMember(d.id, m['fullName'] ?? ''),
                            ),
                        ]),
                      ),
                    ),
                  );
                }).toList());
              },
            );
          },
        ),
      ),
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
  @override void initState() {
  super.initState();
  tab = TabController(length: 10, vsync: this);
  _load();
  // STEP 5: When user opens Chat tab (index 6), mark all as read
  tab.addListener(() {
  if (tab.indexIsChanging) return;
  setState(() {}); // <-- THIS is the fix, rebuilds to hide "?"
  if (tab.index == 6) markChatAsRead();
});
      // PLAN B listener
  FirebaseFirestore.instance.collection('notifications')
    .where('groupId', isEqualTo: widget.groupId)
    .orderBy('createdAt', descending: true).limit(1).snapshots().listen((snap) {
      if (snap.docs.isEmpty) return;
      var n = snap.docs.first.data() as Map<String, dynamic>;
      String sender = n['sender'] ?? '';
      if (sender == widget.currentUser['fullName']) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${n['title']} - ${n['body']}"), duration: const Duration(seconds: 5), backgroundColor: Colors.green),
      );
    });
}
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
  Future<void> addPartialPayment(String mid, String name, int amount) async {
  String r = currentRoundId(widget.groupId);
  var ref = FirebaseFirestore.instance.collection('partial_payments').doc("${widget.groupId}_${r}_$mid");
  var doc = await ref.get();
  int soFar = ((doc.data()?['paidSoFar'] ?? 0) as int) + amount;
  await ref.set({
    'groupId': widget.groupId, 'roundId': r, 'memberId': mid, 'memberName': name,
    'paidSoFar': soFar, 'target': cashGroups[widget.groupId]!.contribution,
    'lastPaidBy': widget.currentUser['fullName'], 'updatedAt': FieldValue.serverTimestamp(),
  });
}
Widget buildSecretary(List<QueryDocumentSnapshot> members) {
  // ONLY Ch.person, Secretary, Treasure can record
  if (!isExec) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              "🔒 Only Ch.person, Secretary or Treasure can record cash.\n\nYou are: ${widget.currentUser['role']}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('partial_payments')
      .where('groupId', isEqualTo: widget.groupId)
      .where('roundId', isEqualTo: currentRoundId(widget.groupId)).snapshots(),
    builder: (ctx, snap) {
      Map<String, int> paidMap = {};
      if (snap.hasData) {
        for (var d in snap.data!.docs) {
          var p = d.data() as Map<String, dynamic>;
          paidMap[p['memberId']] = p['paidSoFar'] ?? 0;
        }
      }
      int target = cashGroups[widget.groupId]!.contribution;
      return ListView(children: [
        Padding(padding: const EdgeInsets.all(12), child: Text("Secretary - Tap name to record cash paid. Target: ${fmt(target)} UGX - ${roundLabel(widget.groupId)}", style: const TextStyle(fontWeight: FontWeight.bold))),
        ...members.map((d) {
          var m = d.data() as Map<String, dynamic>;
          int soFar = paidMap[d.id] ?? 0;
          bool complete = soFar >= target;
          return Card(color: complete ? Colors.green[50] : Colors.white, child: ListTile(
            title: Text(m['fullName'] ?? ''),
            subtitle: Text("Paid: ${fmt(soFar)} / ${fmt(target)} UGX ${complete ? '✅ COMPLETE - Can now mark PAID' : '• Remaining: ${fmt(target - soFar)}'}"),
            trailing: ElevatedButton(
              onPressed: () {
                TextEditingController amtC = TextEditingController();
                showDialog(context: context, builder: (_) => AlertDialog(
                  title: Text("Record cash for ${m['fullName']}"),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text("Already paid: ${fmt(soFar)} / ${fmt(target)}"),
                    const SizedBox(height: 10),
                    TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount paid now (UGX)", border: OutlineInputBorder())),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                    ElevatedButton(onPressed: () async {
                      int amt = int.tryParse(amtC.text) ?? 0;
                      if (amt <= 0) return;
                      Navigator.pop(context);
                      await addPartialPayment(d.id, m['fullName'], amt);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Recorded ${fmt(amt)} for ${m['fullName']} - Total now ${fmt(soFar + amt)}")));
                    }, child: const Text("SAVE")),
                  ],
                ));
              },
              child: Text(complete ? "ADD MORE" : "RECORD"),
            ),
          ));
        }),
      ]);
    },
  );
}
  Future<void> markPaid(String mid, String name) async {
    if (!isExec) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only Ch.person, Secretary or Treasure can mark cash paid"))); return; }
    String r = currentRoundId(widget.groupId);
      // STEP 3: Cannot mark PAID until Secretary recorded full amount
  var pDoc = await FirebaseFirestore.instance.collection('partial_payments').doc("${widget.groupId}_${r}_$mid").get();
  int soFar = (pDoc.data()?['paidSoFar'] ?? 0) as int;
  int target = cashGroups[widget.groupId]!.contribution;
  if (soFar < target) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cannot mark PAID - only ${fmt(soFar)} / ${fmt(target)} recorded by Secretary. Record remaining ${fmt(target - soFar)} first.")));
    return;
  }
    await FirebaseFirestore.instance.collection('cash_payments').doc("${widget.groupId}_${r}_$mid").set({'groupId': widget.groupId, 'roundId': r, 'memberId': mid, 'memberName': name, 'amount': cashGroups[widget.groupId]!.contribution, 'status': 'paid', 'markedBy': widget.currentUser['fullName'], 'markedAt': FieldValue.serverTimestamp()});
    sendPushToGroup(widget.groupId, "✅ Cash PAID - Group ${widget.groupId}", "$name marked PAID", widget.currentUser['fullName']);
    if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name marked PAID")));
  }
  Future<void> unmarkPaid(String mid) async {
    if (!isExec) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only executives can unmark cash"))); return; }
    await FirebaseFirestore.instance.collection('cash_payments').doc("${widget.groupId}_${currentRoundId(widget.groupId)}_$mid").delete();
  }
  Future<void> markReceived(String mid, String name, int amt) async {
  if (!isExec) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only executives can mark received"))); return; }
  String r = currentRoundId(widget.groupId);
  // CHECK 1: Must be PAID first
  var paidDoc = await FirebaseFirestore.instance.collection('cash_payments').doc("${widget.groupId}_${r}_$mid").get();
  if (!paidDoc.exists) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name cannot RECEIVE - not yet marked PAID. Secretary must record full payment first.")));
    return;
  }
  // CHECK 2: Already received this round?
  var recDoc = await FirebaseFirestore.instance.collection('cash_received').doc("${widget.groupId}_${r}_$mid").get();
  if (recDoc.exists) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name already received this round.")));
    return;
  }
    await FirebaseFirestore.instance.collection('cash_received').doc("${widget.groupId}_${r}_$mid").set({
    'groupId': widget.groupId, 'roundId': r, 'memberId': mid, 'memberName': name,
    'amount': amt, 'receivedAt': FieldValue.serverTimestamp(),
    'markedBy': widget.currentUser['fullName'],
  });
  sendPushToGroup(widget.groupId, "🎁 Cash RECEIVED - Group ${widget.groupId}", "$name received ${fmt(amt)} UGX", widget.currentUser['fullName']);
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name marked RECEIVED - ${fmt(amt)} UGX")));
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name marked RECEIVED - ${fmt(amt)} UGX")));
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
  }  // <-- ADD THIS ONE LINE - closes receipt()
  Future<void> aiInfo() async {
  String gid = widget.groupId;
  String r = currentRoundId(gid);
  int target = cashGroups[gid]!.contribution;

  // Show loading first
  showDialog(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 12), Text("AI is checking Group data...")])));

  try {
    var membersSnap = await FirebaseFirestore.instance.collection('members').get();
    var allInGroup = membersSnap.docs.where((d) => inGroup(d.data() as Map<String, dynamic>, gid)).toList();
    int totalMembers = allInGroup.length;

    var paidSnap = await FirebaseFirestore.instance.collection('cash_payments').where('groupId', isEqualTo: gid).where('roundId', isEqualTo: r).get();
    int paidCount = paidSnap.docs.length;
    int notPaidCount = totalMembers - paidCount;
    if (notPaidCount < 0) notPaidCount = 0;
    int totalCollected = paidCount * target;

    var recSnap = await FirebaseFirestore.instance.collection('cash_received').where('groupId', isEqualTo: gid).where('roundId', isEqualTo: r).get();
    String receiver = recSnap.docs.isEmpty ? "No one yet" : (recSnap.docs.first.data() as Map<String, dynamic>)['memberName'] ?? "Unknown";

    var partialSnap = await FirebaseFirestore.instance.collection('partial_payments').where('groupId', isEqualTo: gid).where('roundId', isEqualTo: r).get();
    int partialTotal = 0;
    for (var d in partialSnap.docs) { partialTotal += ((d.data() as Map<String, dynamic>)['paidSoFar'] ?? 0) as int; }

    // Not paid names - first 5
    Set<String> paidIds = paidSnap.docs.map((d) => (d.data() as Map<String, dynamic>)['memberId'] as String).toSet();
    var notPaidNames = allInGroup.where((d) => !paidIds.contains(d.id)).map((d) => (d.data() as Map<String, dynamic>)['fullName'] ?? '').take(5).toList();

    if (!mounted) return;
    Navigator.pop(context); // close loading

    showDialog(context: context, builder: (_) => AlertDialog(
      title: Row(children: [const Icon(Icons.smart_toy, color: Colors.pink), const SizedBox(width: 8), Text("AI - Group $gid Live Info")]),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("🤖 Hello! I am Mama Teachers AI.", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text("📅 Round: ${roundLabel(gid)}"),
        Text("👥 Total Members in Group $gid: $totalMembers"),
        const Divider(),
        Text("✅ Paid: $paidCount of $totalMembers", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        Text("❌ Not Paid: $notPaidCount", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        Text("💰 Total Collected This Round: ${fmt(totalCollected)} UGX"),
        Text("📝 Secretary Partial Total Recorded: ${fmt(partialTotal)} UGX"),
        Text("🎁 Receiver This Round: $receiver"),
        Text("🎯 Contribution: ${fmt(target)} UGX - ${cashGroups[gid]!.cycle}"),
        const SizedBox(height: 10),
        if (notPaidNames.isNotEmpty) ...[
          const Text("Who has not paid yet:", style: TextStyle(fontWeight: FontWeight.bold)),
          ...notPaidNames.map((n) => Text("• $n")),
          if (notPaidCount > 5) Text("... and ${notPaidCount - 5} more"),
        ] else const Text("🎉 Everyone has paid this round!"),
        const SizedBox(height: 10),
        Text("You are: ${widget.currentUser['fullName']} - ${widget.currentUser['role']} in Group $gid"),
        const SizedBox(height: 10),
        const Text("How it works: 1. Secretary records partial cash. 2. When full amount reached, executive marks PAID. 3. One PAID member receives total and is marked RECEIVED. 4. Next round starts automatically.", style: TextStyle(color: Colors.grey, fontSize: 13)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
    ));
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI error: $e")));
  }
}
    Future<void> exportGroupPDF() async {
    String gid = widget.groupId;
    String r = currentRoundId(gid);
    int target = cashGroups[gid]!.contribution;

    // Get live data
    var membersSnap = await FirebaseFirestore.instance.collection('members').get();
    var allInGroup = membersSnap.docs.where((d) => inGroup(d.data() as Map<String, dynamic>, gid)).toList();
    var paidSnap = await FirebaseFirestore.instance.collection('cash_payments').where('groupId', isEqualTo: gid).where('roundId', isEqualTo: r).get();
    Set<String> paidIds = paidSnap.docs.map((d) => (d.data() as Map<String, dynamic>)['memberId'] as String).toSet();
    var recSnap = await FirebaseFirestore.instance.collection('cash_received').where('groupId', isEqualTo: gid).where('roundId', isEqualTo: r).get();
    String receiver = recSnap.docs.isEmpty ? "No one yet" : (recSnap.docs.first.data() as Map<String, dynamic>)['memberName'] ?? "Unknown";

    var w = Material(child: Container(color: Colors.white, padding: const EdgeInsets.all(20), width: 380, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Image.asset('assets/logo.png', width: 50, height: 50, errorBuilder: (_, __, ___) => const Icon(Icons.groups, size: 40, color: Colors.pink)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("MAMA TEACHERS GROUP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text("Group $gid Report - ${roundLabel(gid)}", style: const TextStyle(color: Colors.grey))])]),
      const Divider(),
      Text("Contribution: ${fmt(target)} UGX - ${cashGroups[gid]!.cycle}", style: const TextStyle(fontWeight: FontWeight.bold)),
      Text("Total Members: ${allInGroup.length}"),
      Text("Paid: ${paidIds.length} / ${allInGroup.length}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      Text("Not Paid: ${allInGroup.length - paidIds.length}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      Text("Total Collected: ${fmt(paidIds.length * target)} UGX"),
      Text("Receiver: $receiver"),
      const SizedBox(height: 12),
      const Text("PAID MEMBERS:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      ...allInGroup.where((d) => paidIds.contains(d.id)).map((d) => Text("✅ ${(d.data() as Map<String, dynamic>)['fullName']} - ${fmt(target)} UGX")),
      const SizedBox(height: 8),
      const Text("NOT PAID MEMBERS:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
      ...allInGroup.where((d) => !paidIds.contains(d.id)).map((d) => Text("❌ ${(d.data() as Map<String, dynamic>)['fullName']} - ${m(d)}")),
      const SizedBox(height: 12),
      const Text("Mama Teachers Group - Cash Round", style: TextStyle(color: Colors.grey, fontSize: 12)),
      const Text("Ihsaanu Tech - 0709157254", style: TextStyle(color: Colors.grey, fontSize: 11)),
    ])));

    var img = await shot.captureFromWidget(w);
    var dir = await getTemporaryDirectory();
    var f = File("${dir.path}/Group_${gid}_Report_${DateTime.now().millisecondsSinceEpoch}.png");
    await f.writeAsBytes(img);
    await Share.shareXFiles([XFile(f.path)], text: "Mama Teachers Group $gid Report - ${roundLabel(gid)}");
  }

  String m(QueryDocumentSnapshot d) {
    var data = d.data() as Map<String, dynamic>;
    return data['phone'] ?? '';
  }
  @override Widget build(BuildContext context) {
    var cfg = cashGroups[widget.groupId]!;
    return Scaffold(appBar: AppBar(backgroundColor: cfg.color, foregroundColor: Colors.white, title: Text("Group ${widget.groupId} - ${roundLabel(widget.groupId)}"),
  actions: [
    // STEP 5: Unread chat badge
    StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cash_chats').where('groupId', isEqualTo: widget.groupId).snapshots(),
      builder: (c, snap) {
        int unread = 0;
        if (snap.hasData) {
          String myName = widget.currentUser['fullName'] ?? '';
          unread = snap.data!.docs.where((d) {
            var m = d.data() as Map<String, dynamic>;
            List readBy = m['readBy'] ?? [];
            return !readBy.contains(myName) && m['sender'] != myName;
          }).length;
        }
        return Stack(children: [
          IconButton(icon: const Icon(Icons.chat), onPressed: () { tab.animateTo(6); markChatAsRead(); }),
          if (unread > 0) Positioned(top: 4, right: 6, child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: Text("$unread", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          )),
        ]);
      },
    ),
    IconButton(icon: const Icon(Icons.share), onPressed: exportGroupPDF),
    IconButton(icon: const Text("💿", style: TextStyle(fontSize: 22)), onPressed: () => showAd(context)),
  ],
        bottom: TabBar(controller: tab, isScrollable: true, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: const [Tab(text: "All Members"), Tab(text: "Pay Please"), Tab(text: "Paid ✅"), Tab(text: "Not Paid ❌"), Tab(text: "Received"), Tab(text: "Past"), Tab(text: "Chat"), Tab(text: "Settings"), Tab(text: "Secretary 📝"), Tab(text: "Live 📡")])),
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
        ListTile(leading: const Icon(Icons.edit_note, color: Colors.blue), title: const Text("Secretary - Record Cash"), onTap: () { Navigator.pop(context); tab.animateTo(8); }),        ListTile(leading: const Icon(Icons.live_tv, color: Colors.red), title: const Text("Live Data - This Group"), onTap: () { Navigator.pop(context); tab.animateTo(9); }),
        ListTile(leading: const Icon(Icons.smart_toy), title: const Text("AI Cash Round Info"), onTap: () { Navigator.pop(context); aiInfo(); }),
        ListTile(leading: const Icon(Icons.arrow_back), title: const Text("Back to Cash Round List"), onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),const Divider(),
ListTile(
  leading: const Icon(Icons.logout, color: Colors.red),
  title: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
  onTap: () async {
    Navigator.pop(context); // close drawer first
    // ASK FIRST - Not direct logout
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Logout?"),
        content: Text("Are you sure you want to logout, ${widget.currentUser['fullName']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Yes, Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
        if (confirm == true) {
      // ✅ YOUR logout - clear saved login
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Login()), (r) => false);
    }
  },
),
      ])),
floatingActionButton: tab.index == 6 ? null : FloatingActionButton(
  backgroundColor: cfg.color,
  onPressed: aiInfo,
  child: const Text("?", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
),
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
 return TabBarView(controller: tab, children: [buildAll(all), buildPay(all, paidIds), buildPaid(paidM), buildNotPaid(notPaidM), buildReceived(all, paidIds), buildPast(), buildChat(), buildSettings(), buildSecretary(all), buildLive(all, paidIds)]);
        });
      }));
  }
  Widget buildLive(List<QueryDocumentSnapshot> members, Set<String> paidIds) {
    String r = currentRoundId(widget.groupId);
    int target = cashGroups[widget.groupId]!.contribution;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('partial_payments').where('groupId', isEqualTo: widget.groupId).where('roundId', isEqualTo: r).snapshots(),
      builder: (ctx, partSnap) {
        Map<String, int> paidMap = {};
        if (partSnap.hasData) {
          for (var d in partSnap.data!.docs) {
            var p = d.data() as Map<String, dynamic>;
            paidMap[p['memberId']] = p['paidSoFar'] ?? 0;
          }
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('cash_received').where('groupId', isEqualTo: widget.groupId).where('roundId', isEqualTo: r).snapshots(),
          builder: (ctx2, recSnap) {
            Set<String> recIds = {};
            String receiver = "No one yet";
            if (recSnap.hasData && recSnap.data!.docs.isNotEmpty) {
              for (var d in recSnap.data!.docs) {
                var p = d.data() as Map<String, dynamic>;
                recIds.add(p['memberId']);
                receiver = p['memberName'] ?? receiver;
              }
            }
            int paidCount = members.where((d) => paidIds.contains(d.id)).length;
            return ListView(children: [
              Container(padding: const EdgeInsets.all(14), color: cashGroups[widget.groupId]!.soft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("📡 LIVE DATA - Group ${widget.groupId} - ${roundLabel(widget.groupId)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text("👥 Members: ${members.length}  |  ✅ Paid: $paidCount  |  ❌ Not Paid: ${members.length - paidCount}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("💰 Collected: ${fmt(paidCount * target)} UGX / ${fmt(members.length * target)} UGX"),
                Text("🎁 Receiver: $receiver"),
                const Text("Updates automatically - No need to refresh", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ])),
              ...members.map((d) {
                var m = d.data() as Map<String, dynamic>;
                bool isPaid = paidIds.contains(d.id);
                bool isRec = recIds.contains(d.id);
                int soFar = paidMap[d.id] ?? 0;
                return Card(color: isPaid ? Colors.green[50] : Colors.white, child: ListTile(
                  leading: CircleAvatar(backgroundColor: isPaid ? Colors.green : Colors.red, child: Text((m['fullName'] ?? '?')[0], style: const TextStyle(color: Colors.white))),
                  title: Text(m['fullName'] ?? ''),
                  subtitle: Text("${m['role']} • ${m['phone']}\nSecretary recorded: ${fmt(soFar)} / ${fmt(target)} ${isRec ? '• 🎁 RECEIVED' : ''}"),
                  isThreeLine: true,
                  trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isPaid ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(6)), child: Text(isPaid ? "PAID ✅" : "NOT PAID ❌", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                ));
              }),
            ]);
          },
        );
      },
    );
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
 Widget buildReceived(List<QueryDocumentSnapshot> all, Set<String> paidIds) {
  TextEditingController searchC = TextEditingController();
  String q = ""; // Outside builder so search doesn't reset

  return StatefulBuilder(builder: (ctx, setSt) {
    // 1. Only PAID members can be searched - from Paid card
    var paidMembers = all.where((d) => paidIds.contains(d.id)).toList();

    // 2. Names appear ONLY when you type in search
    var filtered = [];
    if (q.isNotEmpty) {
      filtered = paidMembers.where((d) {
        return ((d.data() as Map<String, dynamic>)['fullName'] ?? '')
            .toString()
            .toLowerCase()
            .contains(q);
      }).toList();
    }

    bool allPaid = all.isNotEmpty && paidMembers.length == all.length;

    return Column(children: [
      // Top status
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: allPaid ? Colors.green.shade100 : Colors.orange.shade100,
        child: Text(
          allPaid
              ? "✅ ALL ${all.length} PAID - Now search receiver"
              : "⏳ ${paidMembers.length} / ${all.length} PAID - Wait for all to pay",
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),

      // Search box
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: searchC,
          onChanged: (v) => setSt(() => q = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: "Search PAID member to mark as RECEIVED...",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),

      // Instruction when no search yet
      if (q.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text("🔍 Type a name above to find the receiver\nOnly PAID members will appear here",
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),

      // No match
      if (q.isNotEmpty && filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text("No PAID member matches that name"),
        ),

      // 3. SEARCH RESULTS LIST - This is where names appear
      if (q.isNotEmpty && filtered.isNotEmpty)
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              var d = filtered[index];
              var m = d.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text((m['fullName'] ?? '?')[0], style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(m['fullName'] ?? ''),
                  subtitle: Text("PAID ✅ • ${m['phone'] ?? ''}"),
                  trailing: ElevatedButton(
                    onPressed: !allPaid
                        ? null
                        : () => markReceived(d.id, m['fullName'], cashGroups[widget.groupId]!.contribution),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: Text(allPaid ? "MARK RECEIVED" : "WAIT", style: const TextStyle(color: Colors.white)),
                  ),
                ),
              );
            },
          ),
        ),

      const Divider(),
      const Text("Received This Round - List:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 6),

      // 4. RECEIVED LIST - Starts building here after you mark received
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('cash_received').where('groupId', isEqualTo: widget.groupId).where('roundId', isEqualTo: currentRoundId(widget.groupId)).snapshots(),
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return const Center(child: Text("No one has received cash yet this round"));
            return ListView.builder(
              itemCount: snap.data!.docs.length,
              itemBuilder: (context, i) {
                var d = snap.data!.docs[i];
                var r = d.data() as Map<String, dynamic>;
                return Card(
                  color: Colors.green[50],
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                    title: Text("${r['memberName']} - RECEIVED ✅"),
                    subtitle: Text("Cash Received: ${fmt(r['amount'])} UGX"),
                    trailing: IconButton(icon: const Icon(Icons.receipt), onPressed: () => receipt("Received Receipt - Cash Round", r['memberName'], r['amount'])),
                  ),
                );
              },
            );
          },
        ),
      ),
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
  Future<void> markChatAsRead() async {
  try {
    var q = await FirebaseFirestore.instance.collection('cash_chats')
        .where('groupId', isEqualTo: widget.groupId).get();
    String myName = widget.currentUser['fullName'] ?? '';
    for (var d in q.docs) {
      var data = d.data() as Map<String, dynamic>;
      List readBy = data['readBy'] ?? [];
      if (!readBy.contains(myName)) {
        await d.reference.update({'readBy': FieldValue.arrayUnion([myName])});
      }
    }
  } catch (_) {}
}
Widget buildChat() {
  TextEditingController chatC = TextEditingController();
  return StatefulBuilder(builder: (ctx, setSt) {
    return Column(children: [
      // Messages list
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('group_chats')
              .where('groupId', isEqualTo: widget.groupId)
              .snapshots(),
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Center(child: Text("No messages yet.\nBe the first to send one!", textAlign: TextAlign.center));
            }
            // Sort in code - avoids Firestore index error that caused infinite loading
            var docs = snap.data!.docs.toList();
            docs.sort((a, b) {
              var ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              var tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (ta == null || tb == null) return 0;
              return ta.compareTo(tb);
            });
            bool isMe(String name) => name == widget.currentUser['fullName'];
            return ListView.builder(
              itemCount: docs.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, i) {
                var doc = docs[i];
                var m = doc.data() as Map<String, dynamic>;
                bool me = isMe(m['senderName'] ?? '');
                return GestureDetector(
                  // LONG-PRESS TO DELETE
                  onLongPress: () async {
                    if (!me) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You can only delete your own message')),
                      );
                      return;
                    }
                    bool ok = await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete message?'),
                        content: Text('Delete "${m['message'] ?? ''}" for everyone?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ) ?? false;
                    if (ok) {
                      await FirebaseFirestore.instance.collection('group_chats').doc(doc.id).delete();
                    }
                  },
                  child: Align(
                    alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: me ? Colors.pink : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['senderName'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: me ? Colors.white : Colors.black54)),
                          Text(m['message'] ?? '', style: TextStyle(color: me ? Colors.white : Colors.black)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      // Input + SEND button - ENABLED
      Container(
        padding: const EdgeInsets.all(8),
        color: Colors.white,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: chatC,
              decoration: InputDecoration(
                hintText: "Type cash message for ${widget.groupId}...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.pink,
            radius: 24,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () async {
                String msg = chatC.text.trim();
                if (msg.isEmpty) return;
                chatC.clear();
                // Push to Firestore - everyone in group will get it instantly
                await FirebaseFirestore.instance.collection('group_chats').add({
                  'groupId': widget.groupId,
                  'senderName': widget.currentUser['fullName'] ?? 'Member',
                  'senderPhone': widget.currentUser['phone'] ?? '',
                  'message': msg,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              },
            ),
          ),
        ]),
      ),
    ]);
  });
}
    Widget buildSettings() {
  if (!isExec) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        "🔒 Only Ch.person, Secretary or Treasure of Group ${widget.groupId} can open Settings.\n\nYou are: ${widget.currentUser['role']}",
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey),
      ),
    ));
  }
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
      const SizedBox(height: 15), Text("Current: ${fmt(cashGroups[widget.groupId]!.contribution)} UGX - $cycle - Round: ${roundLabel(widget.groupId)}", style: const TextStyle(color: Colors.grey)),      const SizedBox(height: 25),
      const Divider(),
      Text("Members in Group ${widget.groupId} - Executive can remove", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
      const SizedBox(height: 10),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('members').snapshots(),
        builder: (c, snap) {
          if (!snap.hasData) return const SizedBox();
          var list = snap.data!.docs.where((d) => inGroup(d.data() as Map<String, dynamic>, widget.groupId)).toList();
          return Column(children: list.map((d) {
            var m = d.data() as Map<String, dynamic>;
            return Card(child: ListTile(
              title: Text(m['fullName'] ?? ''),
              subtitle: Text("${m['role']} • ${m['phone']}"),
              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                bool ok = await showDialog(context: context, builder: (_) => AlertDialog(
                  title: Text("Remove ${m['fullName']} from Group ${widget.groupId}?"),
                  content: const Text("This deletes them from the App. Only executive can do this."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
                  ],
                )) ?? false;
                if (!ok) return;
                await FirebaseFirestore.instance.collection('members').doc(d.id).delete();
              }),
            ));
          }).toList());
        },
      ),
    ])));
  }
}
