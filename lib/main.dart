import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode; // Importeer kDebugMode
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:html' as html; // Alleen voor Jira export op web

// Importeer het data models bestand
import 'data_models.dart';

// --- MAIN FUNCTIE & SUPABASE INITIALISATIE ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String supabaseUrl;
  String supabaseAnonKey;

  // Probeer eerst omgevingsvariabelen te lezen die via --dart-define zijn ingesteld (bijv. in CI/CD)
  // De waarden zijn leeg als ze niet zijn ingesteld, vandaar de isEmpty check.
  const String definedUrl = String.fromEnvironment('SUPABASE_URL');
  const String definedAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (definedUrl.isNotEmpty && definedAnonKey.isNotEmpty) {
    // Gebruik de variabelen die tijdens de build zijn ingevoegd (productie)
    supabaseUrl = definedUrl;
    supabaseAnonKey = definedAnonKey;
  } else {
    // Als we niet in een release build zijn met --dart-define (d.w.z. in debug modus lokaal),
    // laad dan vanuit het .env bestand.
    if (kDebugMode) {
      await dotenv.load(fileName: ".env");
      supabaseUrl = dotenv.env['SUPABASE_URL']!;
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
    } else {
      // Dit geval zou niet moeten voorkomen in een goed geconfigureerde release build.
      // Het is een veiligheidscheck om te voorkomen dat de app zonder credentials draait.
      throw Exception(
          "Supabase credentials niet gevonden. Zorg voor een .env bestand (debug) of stel --dart-define variabelen in (release).");
    }
  }

  // Initialiseer Supabase met de gevonden URL en Anon Key
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const AcceptanceTesterApp());
}

// Helper om snel toegang te krijgen tot de Supabase client
final supabase = Supabase.instance.client;

class AcceptanceTesterApp extends StatelessWidget {
  const AcceptanceTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    const medAppBlue = Color(0xFF0054A6);
    const medAppGreen = Color(0xFF00A69C);
    const appBackgroundColor = Color(0xFFF8F9FA);

    return MaterialApp(
      title: 'Acceptance Test Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: medAppBlue,
            primary: medAppBlue,
            secondary: medAppGreen,
            surface: Colors.white,
            background: appBackgroundColor,
            brightness: Brightness.light),
        useMaterial3: true,
        scaffoldBackgroundColor: appBackgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: appBackgroundColor,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          filled: true,
          fillColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
          backgroundColor: medAppGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: 0,
        )),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: medAppBlue,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black54,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        )),
      ),
      home: const AuthHandlerScreen(), // Start met de Auth Handler
    );
  }
}
// --- AUTHENTICATIE ---

class AuthHandlerScreen extends StatelessWidget {
  const AuthHandlerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Luister naar de auth state changes van Supabase
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Als de gebruiker is ingelogd, ga naar de RoleSelectionScreen
        if (snapshot.hasData && snapshot.data?.session != null) {
          return const RoleSelectionScreen();
        }
        // Anders, toon de LoginScreen
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kDebugMode ? null : 'nl.medapp.acceptancetester://login-callback/',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Fout bij inloggen: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network('https://www.medapp.nl/wp-content/uploads/2022/05/logo-medapp.svg',
                height: 60,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.medical_services_outlined, size: 60)),
            const SizedBox(height: 20),
            Text("Acceptance Test Platform",
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 70),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                icon: Image.asset(
                  'Google Symbol.png',
                  height: 24,
                ),
                label: const Text('Inloggen met Google'),
                onPressed: _signInWithGoogle,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(280, 60),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey.shade300)),
              ),
          ],
        ),
      ),
    );
  }
}

// --- GEDEELDE WIDGETS ---

class RoleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const RoleButton({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 24),
      label: Text(label),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(280, 60),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class Base64Image extends StatelessWidget {
  final String base64String;
  final double? width;
  final double? height;
  final BoxFit fit;

  const Base64Image({
    super.key,
    required this.base64String,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final decodedBytes = base64Decode(base64String);
      return Image.memory(
        decodedBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
            width: width,
            height: height,
            color: Colors.red.shade100,
            child: const Icon(Icons.error)),
      );
    } catch (e) {
      return Container(
          width: width,
          height: height,
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image));
    }
  }
}

// --- SCHERMEN ---

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 'Gebruiker';

    return Scaffold(
      appBar: AppBar(
        title: Text("Welkom, $userName"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Uitloggen',
            onPressed: () async {
              await supabase.auth.signOut();
            },
          )
        ],
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoleButton(
                icon: Icons.person_outline,
                label: 'Ik ben een Tester',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const TesterHomeScreen()))),
            const SizedBox(height: 20),
            RoleButton(
                icon: Icons.supervisor_account_outlined,
                label: 'Ik ben Product Owner',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const PoHomeScreen()))),
          ],
        ),
      ),
    );
  }
}

class TesterHomeScreen extends StatefulWidget {
  const TesterHomeScreen({super.key});

  @override
  State<TesterHomeScreen> createState() => _TesterHomeScreenState();
}

class _TesterHomeScreenState extends State<TesterHomeScreen> {
  // Real-time stream van testplannen
  final _stream = supabase.from('test_plans').stream(primaryKey: ['id']);

  void _openPlan(TestPlan plan) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => TesterWizardScreen(plan: plan),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Beschikbare Testen")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Fout bij laden: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text('Er zijn momenteel geen testplannen beschikbaar.',
                      style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          final plans = snapshot.data!.map((json) => TestPlan.fromJson(json)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final isCompletedByMe = plan.testerId == supabase.auth.currentUser?.id;
              final isBeingTested = plan.testerId != null && !isCompletedByMe;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isCompletedByMe
                    ? Colors.green.shade50
                    : (isBeingTested ? Colors.orange.shade50 : null),
                child: ListTile(
                  leading: Icon(
                    isCompletedByMe
                        ? Icons.check_circle
                        : (isBeingTested ? Icons.person : Icons.assignment_outlined),
                    color: isCompletedByMe
                        ? Colors.green
                        : (isBeingTested ? Colors.orange : Colors.grey),
                  ),
                  title: Text("${plan.productName} v${plan.version}"),
                  subtitle: Text(isCompletedByMe
                      ? "Voltooid door jou"
                      : (isBeingTested
                          ? "Wordt getest door ${plan.testerName}"
                          : "Klaar om te testen")),
                  trailing: isBeingTested ? null : const Icon(Icons.arrow_forward_ios),
                  onTap: isBeingTested ? null : () => _openPlan(plan),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PoHomeScreen extends StatefulWidget {
  const PoHomeScreen({super.key});

  @override
  State<PoHomeScreen> createState() => _PoHomeScreenState();
}

class _PoHomeScreenState extends State<PoHomeScreen> {
  // Real-time stream van testplannen
  final _stream = supabase.from('test_plans').stream(primaryKey: ['id']).order('created_at');

  void _onPlanAction(TestPlan plan, String action) async {
    switch (action) {
      case 'edit':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => PoCreatePlanWizard(existingPlan: plan),
        ));
        break;
      case 'duplicate':
        final newPlan = TestPlan(
          // Supabase genereert de ID, dus we geven er geen mee.
          productName: "${plan.productName} (Kopie)",
          version: plan.version,
          steps: plan.steps
              .map((s) => s.copyWith(id: DateTime.now().millisecondsSinceEpoch + s.id))
              .toList(),
          testDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          ownerId: supabase.auth.currentUser!.id,
        );
        try {
          await supabase.from('test_plans').insert(newPlan.toSupabaseJson());
        } catch (e) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Fout bij dupliceren: $e')));
        }
        break;
      case 'results':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => PoDashboardScreen(plan: plan),
        ));
        break;
      case 'delete':
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Plan Verwijderen?'),
                  content: Text(
                      'Weet je zeker dat je "${plan.productName} v${plan.version}" wilt verwijderen? Dit kan niet ongedaan worden gemaakt.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuleren')),
                    FilledButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          try {
                            // FIX 2: Gebruik plan.id! om de compiler te verzekeren dat het niet null is.
                            await supabase.from('test_plans').delete().match({'id': plan.id!});
                          } catch (e) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('Fout bij verwijderen: $e')));
                          }
                        },
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Verwijder')),
                  ],
                ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mijn Testplannen"),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Fout bij laden: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text('Je hebt nog geen testplannen gemaakt.', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          final plans = snapshot.data!
              .map((json) => TestPlan.fromJson(json))
              .where((p) => p.ownerId == supabase.auth.currentUser?.id) // Filter op eigenaar
              .toList();

          if (plans.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text('Je hebt nog geen testplannen gemaakt.', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              return _PoPlanListItem(
                plan: plans[index],
                onAction: (action) => _onPlanAction(plans[index], action),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const PoCreatePlanWizard(),
          ));
        },
        label: const Text('Nieuw Plan'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _PoPlanListItem extends StatefulWidget {
  final TestPlan plan;
  final Function(String action) onAction;

  const _PoPlanListItem({required this.plan, required this.onAction});

  @override
  State<_PoPlanListItem> createState() => _PoPlanListItemState();
}

class _PoPlanListItemState extends State<_PoPlanListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool hasResults = widget.plan.testerId != null && widget.plan.testerId!.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(hasResults ? Icons.fact_check_outlined : Icons.description_outlined,
                  color: hasResults ? Theme.of(context).colorScheme.primary : Colors.grey),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.plan.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Versie: ${widget.plan.version}"),
                    if (hasResults)
                      Text("Getest door: ${widget.plan.testerName}",
                          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: _isHovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    if (hasResults)
                      IconButton(
                          icon: const Icon(Icons.bar_chart),
                          tooltip: 'Bekijk Resultaten',
                          onPressed: () => widget.onAction('results')),
                    IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Bewerken',
                        onPressed: () => widget.onAction('edit')),
                    IconButton(
                        icon: const Icon(Icons.copy_outlined),
                        tooltip: 'Dupliceren',
                        onPressed: () => widget.onAction('duplicate')),
                    IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Verwijderen',
                        onPressed: () => widget.onAction('delete')),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class PoCreatePlanWizard extends StatefulWidget {
  final TestPlan? existingPlan;
  const PoCreatePlanWizard({super.key, this.existingPlan});

  @override
  State<PoCreatePlanWizard> createState() => _PoCreatePlanWizardState();
}

class _PoCreatePlanWizardState extends State<PoCreatePlanWizard> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _versionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _stepTitleController = TextEditingController();
  final _stepDescController = TextEditingController();

  List<String> _categories = ['Algemeen'];
  String _selectedCategoryForNewStep = 'Algemeen';
  List<TestStep> _steps = [];
  int _selectedStepIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.existingPlan != null) {
      final plan = widget.existingPlan!;
      _productNameController.text = plan.productName;
      _versionController.text = plan.version;
      _steps = List.from(plan.steps.map((s) => s.copyWith())); // Deep copy
      final existingCategories = _steps.map((s) => s.category).toSet().toList();
      _categories = {'Algemeen', ...existingCategories}.toList();
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _versionController.dispose();
    _categoryController.dispose();
    _stepTitleController.dispose();
    _stepDescController.dispose();
    super.dispose();
  }

  void _addCategory() {
    final categoryName = _categoryController.text.trim();
    if (categoryName.isNotEmpty && !_categories.contains(categoryName)) {
      setState(() {
        _categories.add(categoryName);
        _selectedCategoryForNewStep = categoryName;
        _categoryController.clear();
      });
    }
  }

  void _addStep() {
    final title = _stepTitleController.text.trim();
    final description = _stepDescController.text.trim();
    if (title.isNotEmpty) {
      setState(() {
        final newStep = TestStep(
          id: DateTime.now().millisecondsSinceEpoch,
          title: title,
          description: description,
          category: _selectedCategoryForNewStep,
          poImageUrls: [],
        );
        _steps.add(newStep);
        _selectedStepIndex = _steps.length - 1;
      });
      _stepTitleController.clear();
      _stepDescController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _savePlan() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Voeg ten minste één teststap toe.")));
      return;
    }

    final plan = TestPlan(
      id: widget.existingPlan?.id, // Kan null zijn voor een nieuw plan
      productName: _productNameController.text,
      version: _versionController.text,
      steps: _steps,
      testDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      ownerId: supabase.auth.currentUser!.id,
    );

    try {
      // Upsert: update als ID bestaat, insert als het nieuw is.
      await supabase.from('test_plans').upsert(plan.toSupabaseJson());

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Plan opgeslagen in de cloud!')));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fout bij opslaan: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.existingPlan == null ? 'Nieuw Testplan' : 'Bewerk Testplan')),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Panel
            SizedBox(
              width: 350,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Plan Informatie", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _productNameController,
                        validator: (v) => v!.isEmpty ? 'Productnaam is verplicht' : null,
                        decoration: const InputDecoration(labelText: "Productnaam")),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _versionController,
                        validator: (v) => v!.isEmpty ? 'Versie is verplicht' : null,
                        decoration: const InputDecoration(labelText: "Versie (bv. v1.2.0)")),
                    const Divider(height: 48),
                    Text("Categorieën", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                                controller: _categoryController,
                                decoration: const InputDecoration(labelText: "Nieuwe categorie"))),
                        IconButton(onPressed: _addCategory, icon: const Icon(Icons.add_circle))
                      ],
                    ),
                    const Divider(height: 48),
                    Text("Nieuwe Stap Toevoegen", style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryForNewStep,
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategoryForNewStep = val);
                      },
                      decoration: const InputDecoration(labelText: 'Kies categorie'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _stepTitleController,
                        decoration: const InputDecoration(labelText: "Titel van de stap")),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _stepDescController,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: "Optionele beschrijving")),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                        onPressed: _addStep,
                        icon: const Icon(Icons.add),
                        label: const Text("Stap Toevoegen")),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            // Right Panel
            Expanded(
              child: _steps.isEmpty
                  ? const Center(child: Text("Voeg stappen toe..."))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _steps.length,
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        final bool isActive = _selectedStepIndex == index;
                        return _TimelineStepItem(
                          key: ValueKey(step.id),
                          stepNumber: index + 1,
                          isFirst: index == 0,
                          isLast: index == _steps.length - 1,
                          isActive: isActive,
                          isReorderable: true,
                          child: isActive
                              ? _PoEditableStepCard(
                                  step: step,
                                  onRemove: () => setState(() => _steps.removeAt(index)),
                                )
                              : _InactiveStepTitle(
                                  step: step,
                                  onTap: () => setState(() => _selectedStepIndex = index),
                                ),
                        );
                      },
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _steps.removeAt(oldIndex);
                          _steps.insert(newIndex, item);
                          // Update selected index to follow the moved item
                          if (_selectedStepIndex == oldIndex) {
                            _selectedStepIndex = newIndex;
                          } else if (_selectedStepIndex >= newIndex &&
                              _selectedStepIndex < oldIndex) {
                            _selectedStepIndex++;
                          } else if (_selectedStepIndex <= newIndex &&
                              _selectedStepIndex > oldIndex) {
                            _selectedStepIndex--;
                          }
                        });
                      },
                    ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _savePlan,
        label: const Text('Plan Opslaan'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}

class _PoEditableStepCard extends StatefulWidget {
  final TestStep step;
  final VoidCallback onRemove;
  const _PoEditableStepCard({required this.step, required this.onRemove});

  @override
  State<_PoEditableStepCard> createState() => _PoEditableStepCardState();
}

class _PoEditableStepCardState extends State<_PoEditableStepCard> {
  late TextEditingController _titleController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.step.title);
    _descController = TextEditingController(text: widget.step.description);
  }

  @override
  void didUpdateWidget(covariant _PoEditableStepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step.title != _titleController.text) {
      _titleController.text = widget.step.title;
    }
    if (widget.step.description != _descController.text) {
      _descController.text = widget.step.description;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickPoImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      final base64String = base64Encode(result.files.single.bytes!);
      setState(() {
        widget.step.poImageUrls.add(base64String);
      });
    }
  }

  void _removePoImage(int imageIndex) {
    setState(() {
      widget.step.poImageUrls.removeAt(imageIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24, right: 20),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.step.category,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              onChanged: (value) => widget.step.title = value,
              decoration: const InputDecoration(labelText: 'Titel'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _descController,
              onChanged: (value) => widget.step.description = value,
              decoration: const InputDecoration(labelText: 'Beschrijving'),
              maxLines: 4,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text("Afbeeldingen", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...widget.step.poImageUrls.mapIndexed((i, url) => Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Base64Image(base64String: url, width: 80, height: 80)),
                        InkWell(
                          onTap: () => _removePoImage(i),
                          child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, color: Colors.white, size: 14)),
                        ),
                      ],
                    )),
                InkWell(
                  onTap: _pickPoImage,
                  child: DottedBorder(
                    borderType: BorderType.RRect,
                    color: Colors.grey.shade400,
                    strokeWidth: 1.5,
                    dashPattern: const [6, 6],
                    radius: const Radius.circular(8),
                    child: const SizedBox(
                        width: 80,
                        height: 80,
                        child: Center(child: Icon(Icons.add_a_photo_outlined, color: Colors.grey))),
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onRemove,
                  tooltip: 'Verwijder stap'),
            ),
          ],
        ),
      ),
    );
  }
}

class TesterWizardScreen extends StatefulWidget {
  final TestPlan plan;
  const TesterWizardScreen({super.key, required this.plan});

  @override
  State<TesterWizardScreen> createState() => _TesterWizardScreenState();
}

class _TesterWizardScreenState extends State<TesterWizardScreen> {
  late TestPlan _testPlan;
  int _currentStepIndex = 0;
  final _testerNameController = TextEditingController();
  final _testAccountController = TextEditingController();
  final List<String> _createdAccounts = [];
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    // FIX 1: Gebruik de `toSupabaseJson` methode om een correcte Map te krijgen voor de `fromJson` factory.
    _testPlan = TestPlan.fromJson(widget.plan.toSupabaseJson());
    _testerNameController.text = supabase.auth.currentUser?.userMetadata?['full_name'] ?? '';
    // Markeer het plan als 'in progress' door deze gebruiker
    _claimTestPlan();
  }

  Future<void> _claimTestPlan() async {
    try {
      await supabase.from('test_plans').update({
        'tester_id': supabase.auth.currentUser!.id,
        'tester_name': supabase.auth.currentUser!.userMetadata?['full_name'] ?? 'Onbekende Tester'
      }).match({'id': _testPlan.id!});
    } catch (e) {
      // Kan gebeuren als iemand anders net iets sneller was.
      // De UI in TesterHomeScreen zou dit moeten opvangen.
      print("Fout bij claimen testplan: $e");
    }
  }

  @override
  void dispose() {
    _testerNameController.dispose();
    _testAccountController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStepIndex < _testPlan.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
    } else {
      _confirmFinish();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    }
  }

  Future<void> _updatePlanInSupabase() async {
    try {
      await supabase
          .from('test_plans')
          .update(_testPlan.toSupabaseJson())
          .match({'id': _testPlan.id!});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Fout bij synchroniseren met de cloud: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _finishTest() async {
    setState(() {
      _isFinishing = true;
    });

    _testPlan.testerName = _testerNameController.text.trim();
    _testPlan.testerId = supabase.auth.currentUser!.id;
    _testPlan.createdTestAccounts = List.from(_createdAccounts);

    // Set final pass/fail status based on findings
    for (var step in _testPlan.steps) {
      step.result = step.finding.trim().isEmpty ? 'pass' : 'fail';
    }

    if (_testPlan.testerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vul je naam in voordat je de test afrondt.")));
      setState(() {
        _isFinishing = false;
      });
      return;
    }

    // Verstuur de finale versie naar Supabase
    await _updatePlanInSupabase();

    setState(() {
      _isFinishing = false;
    });

    if (mounted) {
      Navigator.of(context).pop(); // Sluit de dialog
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                title: const Text('Test afgerond!'),
                content: const Text(
                    'Je resultaten zijn opgeslagen en direct zichtbaar voor de Product Owner.'),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      child: const Text('Terug naar Start'))
                ],
              ));
    }
  }

  void _addTestAccount(StateSetter setState) {
    final email = _testAccountController.text.trim();
    if (email.isNotEmpty && !_createdAccounts.contains(email)) {
      setState(() {
        _createdAccounts.add(email);
        _testAccountController.clear();
      });
    }
  }

  void _removeTestAccount(StateSetter setState, String email) {
    setState(() {
      _createdAccounts.remove(email);
    });
  }

  void _confirmFinish() {
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: const Text('Test Afronden?'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Controleer je naam en voeg eventuele testaccounts toe die je hebt aangemaakt.'),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _testerNameController,
                        decoration: const InputDecoration(labelText: 'Jouw Naam'),
                        autofocus: true,
                      ),
                      const SizedBox(height: 24),
                      const Text('Aangemaakte Testaccounts:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: TextField(
                                  controller: _testAccountController,
                                  onSubmitted: (_) => _addTestAccount(setState),
                                  decoration: const InputDecoration(hintText: 'test@email.com'))),
                          IconButton(
                              icon: const Icon(Icons.add_circle),
                              onPressed: () => _addTestAccount(setState))
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._createdAccounts.map((email) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.person, size: 18),
                            title: Text(email),
                            trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => _removeTestAccount(setState, email)),
                          )),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
                FilledButton(
                  onPressed: _isFinishing ? null : _finishTest,
                  child: _isFinishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ))
                      : const Text('Ja, Afronden'),
                ),
              ],
            );
          });
        });
  }

  Widget _buildNavigation() {
    bool isLastStep = _currentStepIndex == _testPlan.steps.length - 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStepIndex > 0)
            OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text("Vorige"))
          else
            const SizedBox(), // Placeholder to keep space

          ElevatedButton.icon(
            onPressed: _nextStep,
            label: Text(isLastStep ? "Test Afronden" : "Volgende"),
            icon: Icon(isLastStep ? Icons.check_circle_outline : Icons.arrow_forward),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_testPlan.steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${_testPlan.productName} - v${_testPlan.version}')),
        body: const Center(child: Text("Dit testplan bevat geen stappen.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_testPlan.productName} - v${_testPlan.version}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: "Test afbreken",
          onPressed: () async {
            // Geef het plan weer vrij
            await supabase
                .from('test_plans')
                .update({'tester_id': null, 'tester_name': null}).match({'id': _testPlan.id!});
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _testPlan.steps.length,
            itemBuilder: (context, index) {
              final step = _testPlan.steps[index];
              final bool isActive = _currentStepIndex == index;
              return _TimelineStepItem(
                stepNumber: index + 1,
                isFirst: index == 0,
                isLast: index == _testPlan.steps.length - 1,
                isActive: isActive,
                child: isActive
                    ? _ActiveStepCard(
                        step: step,
                        onDataChanged: _updatePlanInSupabase,
                      )
                    : _InactiveStepTitle(
                        step: step,
                        onTap: () => setState(() => _currentStepIndex = index),
                      ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _buildNavigation(),
    );
  }
}

// Private widget for the timeline item structure
class _TimelineStepItem extends StatelessWidget {
  final int stepNumber;
  final bool isFirst;
  final bool isLast;
  final bool isActive;
  final Widget child;
  final bool isReorderable;

  const _TimelineStepItem({
    super.key,
    required this.stepNumber,
    required this.isFirst,
    required this.isLast,
    required this.isActive,
    required this.child,
    this.isReorderable = false,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.grey.shade300;
    final activeColor = Colors.grey.shade800;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline GFX
          SizedBox(
            width: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (isReorderable)
                  ReorderableDragStartListener(
                    index: stepNumber - 1,
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  )
                else
                  const SizedBox(height: 20), // Vertical padding

                // The circle
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: isActive ? activeColor : inactiveColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$stepNumber',
                      style: TextStyle(
                        color: isActive ? activeColor : inactiveColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                // Line below the circle
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : inactiveColor,
                  ),
                )
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              // Align content with the circle
              padding: const EdgeInsets.only(top: 20.0),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// Private widget for the title of an inactive step
class _InactiveStepTitle extends StatelessWidget {
  final TestStep step;
  final VoidCallback onTap;

  const _InactiveStepTitle({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          step.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

// Private widget for the content card of the active step
class _ActiveStepCard extends StatefulWidget {
  final TestStep step;
  final VoidCallback onDataChanged;
  const _ActiveStepCard({required this.step, required this.onDataChanged});

  @override
  State<_ActiveStepCard> createState() => _ActiveStepCardState();
}

class _ActiveStepCardState extends State<_ActiveStepCard> {
  Future<void> _pickTesterImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      final base64String = base64Encode(result.files.single.bytes!);
      setState(() {
        widget.step.testerImageUrls.add(base64String);
      });
      widget.onDataChanged();
    }
  }

  void _removeTesterImage(int imageIndex) {
    setState(() {
      widget.step.testerImageUrls.removeAt(imageIndex);
    });
    widget.onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24, right: 20),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.step.category,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.step.title, style: Theme.of(context).textTheme.headlineMedium),
            const Divider(height: 32),
            Text(widget.step.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5)),
            if (widget.step.poImageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text("Afbeeldingen van PO", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.step.poImageUrls
                    .map((base64) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Base64Image(
                            base64String: base64, width: 120, height: 120, fit: BoxFit.cover)))
                    .toList(),
              )
            ],
            const Divider(height: 48),
            Text('Bevindingen',
                style:
                    Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.step.finding,
              onChanged: (value) {
                widget.step.finding = value;
                widget.onDataChanged();
              },
              decoration: const InputDecoration(
                  hintText:
                      'Als de stap slaagt, laat dit leeg. Anders, beschrijf hier wat er mis ging...'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Text('Voeg screenshots toe om je bevinding te ondersteunen:',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...widget.step.testerImageUrls.mapIndexed((i, url) => Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Base64Image(base64String: url, width: 80, height: 80)),
                        InkWell(
                            onTap: () => _removeTesterImage(i),
                            child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close, color: Colors.white, size: 14))),
                      ],
                    )),
                InkWell(
                  onTap: _pickTesterImage,
                  child: DottedBorder(
                      borderType: BorderType.RRect,
                      color: Colors.grey.shade400,
                      strokeWidth: 1.5,
                      dashPattern: const [6, 6],
                      radius: const Radius.circular(8),
                      child: const SizedBox(
                          width: 80,
                          height: 80,
                          child: Center(
                              child: Icon(
                            Icons.add_a_photo_outlined,
                            color: Colors.grey,
                          )))),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PoDashboardScreen extends StatefulWidget {
  final TestPlan plan;
  const PoDashboardScreen({super.key, required this.plan});

  @override
  State<PoDashboardScreen> createState() => _PoDashboardScreenState();
}

class _PoDashboardScreenState extends State<PoDashboardScreen> {
  final ScrollController _scrollController = ScrollController();

  // We gebruiken de ID van het plan om naar updates te luisteren
  late final Stream<List<Map<String, dynamic>>> _planStream;

  @override
  void initState() {
    super.initState();
    _planStream = supabase.from('test_plans').stream(primaryKey: ['id']).eq('id', widget.plan.id!);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCategory(BuildContext context, Map<String, GlobalKey> keys, String category) {
    final key = keys[category];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(key.currentContext!,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  void _copyEmailsToClipboard(List<String> accounts) {
    if (accounts.isEmpty) return;
    final emails = accounts.join('\n');
    Clipboard.setData(ClipboardData(text: emails)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mailadressen gekopieerd!')),
      );
    });
  }

  void _exportForJira(TestPlan plan) {
    final buffer = StringBuffer();
    buffer.writeln('h2. Testresultaten voor ${plan.productName} v${plan.version}');
    buffer.writeln('Getest door: *${plan.testerName}*');
    buffer.writeln('Testdatum: *${plan.testDate}*');
    buffer.writeln(); // Adds a newline

    final findings = plan.steps.where((s) => s.result == 'fail').toList();

    if (findings.isEmpty) {
      buffer.writeln('Alle testen zijn geslaagd. Geen bevindingen.');
    } else {
      final groupedByCategory = groupBy(findings, (TestStep step) => step.category);

      groupedByCategory.forEach((category, steps) {
        buffer.writeln('h3. Categorie: $category');
        for (var step in steps) {
          buffer.writeln('---'); // Separator
          buffer.writeln('*Stap:* ${step.title}');
          buffer.writeln('*Bevinding:*');
          buffer.writeln('{quote}${step.finding.trim()}{quote}');
          buffer.writeln('*Actie:* ${poActionStatusToString(step.poAction)}');
          if (step.testerImageUrls.isNotEmpty) {
            buffer.writeln(
                '*{color:gray}(Er zijn ${step.testerImageUrls.length} afbeelding(en) bij deze bevinding){color}*');
          }
          buffer.writeln();
        }
      });
    }

    if (plan.createdTestAccounts.isNotEmpty) {
      buffer.writeln('h3. Aangemaakte Testaccounts');
      for (var email in plan.createdTestAccounts) {
        buffer.writeln('* $email');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString())).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jira-tekst gekopieerd naar klembord!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _planStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text('Fout: ${snapshot.error}')));
        }
        // Neem de laatste versie van het plan uit de stream, of de initiële als er nog geen update is
        final planData = snapshot.data?.firstOrNull;
        final plan = planData != null ? TestPlan.fromJson(planData) : widget.plan;

        final findings = plan.steps.where((s) => s.result == 'fail').toList();
        final groupedFindings = groupBy(findings, (TestStep step) => step.category);
        final categories = groupedFindings.keys.toList();
        final categoryKeys = {for (var cat in categories) cat: GlobalKey()};
        if (plan.createdTestAccounts.isNotEmpty) {
          categoryKeys['Testaccounts'] = GlobalKey();
        }

        final bool hasFindings = groupedFindings.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text('Resultaten: ${plan.productName} v${plan.version}'),
            actions: [
              IconButton(
                  onPressed: () => _exportForJira(plan),
                  icon: const Icon(Icons.copy_all),
                  tooltip: 'Kopieer voor Jira'),
              const SizedBox(width: 8)
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Navigation
              _PoDashboardNavMenu(
                categoryKeys: categoryKeys,
                onCategorySelected: (cat) => _scrollToCategory(context, categoryKeys, cat),
                hasTestAccounts: plan.createdTestAccounts.isNotEmpty,
              ),
              const VerticalDivider(width: 1),
              // Main Content
              Expanded(
                child: !hasFindings && plan.createdTestAccounts.isEmpty
                    ? const Center(
                        child: Text(
                            "Alle testen zijn geslaagd en er zijn geen testaccounts aangemaakt."))
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (plan.createdTestAccounts.isNotEmpty)
                            _CategoryHeader(
                              key: categoryKeys['Testaccounts']!,
                              title: 'Aangemaakte Testaccounts',
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Testaccounts',
                                              style: Theme.of(context).textTheme.titleLarge),
                                          IconButton(
                                              onPressed: () =>
                                                  _copyEmailsToClipboard(plan.createdTestAccounts),
                                              icon: const Icon(Icons.copy),
                                              tooltip: 'Kopieer e-mails'),
                                        ],
                                      ),
                                      const Divider(),
                                      ...plan.createdTestAccounts.map((email) => ListTile(
                                            leading: const Icon(Icons.person),
                                            title: Text(email),
                                          ))
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (!hasFindings && plan.createdTestAccounts.isNotEmpty)
                            const Center(
                                child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('Alle testen zijn geslaagd!'),
                            )),
                          ...groupedFindings.entries.map((entry) {
                            final category = entry.key;
                            final steps = entry.value;
                            return _CategoryHeader(
                              key: categoryKeys[category]!,
                              title: category,
                              child: Column(
                                children: steps
                                    .map((step) => _PoFindingCard(step: step, planId: plan.id!))
                                    .toList(),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PoDashboardNavMenu extends StatelessWidget {
  final Map<String, GlobalKey> categoryKeys;
  final Function(String) onCategorySelected;
  final bool hasTestAccounts;

  const _PoDashboardNavMenu({
    required this.categoryKeys,
    required this.onCategorySelected,
    required this.hasTestAccounts,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Inhoudsopgave", style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          if (hasTestAccounts)
            ListTile(
              leading: const Icon(Icons.person_search),
              title: const Text('Testaccounts'),
              onTap: () => onCategorySelected('Testaccounts'),
            ),
          ...categoryKeys.keys.where((k) => k != 'Testaccounts').map((category) => ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(category),
                onTap: () => onCategorySelected(category),
              )),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  final Widget child;

  const _CategoryHeader({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        child,
      ],
    );
  }
}

class _PoFindingCard extends StatefulWidget {
  final TestStep step;
  final int planId;
  const _PoFindingCard({required this.step, required this.planId});

  @override
  State<_PoFindingCard> createState() => _PoFindingCardState();
}

class _PoFindingCardState extends State<_PoFindingCard> {
  Future<void> _updateAction(PoActionStatus newStatus) async {
    // Toggle off if the same button is clicked again
    final finalStatus = widget.step.poAction == newStatus ? PoActionStatus.geenActie : newStatus;

    // Update de lokale state voor directe feedback
    setState(() {
      widget.step.poAction = finalStatus;
    });

    // Update de database
    try {
      // Haal het huidige plan op
      final response =
          await supabase.from('test_plans').select('steps').eq('id', widget.planId).single();

      final stepsData = response['steps'] as List;
      final steps = stepsData.map((s) => TestStep.fromJson(s)).toList();

      // Vind de specifieke stap en update de actie
      final stepIndex = steps.indexWhere((s) => s.id == widget.step.id);
      if (stepIndex != -1) {
        steps[stepIndex].poAction = finalStatus;

        // Sla de gehele lijst met stappen weer op
        await supabase
            .from('test_plans')
            .update({'steps': steps.map((s) => s.toJson()).toList()}).eq('id', widget.planId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Fout bij updaten actie: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.step.title, style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 24),
                  Text('Bevinding van tester:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(widget.step.finding.isEmpty ? '(geen)' : widget.step.finding),
                  if (widget.step.testerImageUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.step.testerImageUrls
                          .map((base64) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Base64Image(base64String: base64, width: 200, height: 200),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionChip(
                  label: 'Must Fix',
                  status: PoActionStatus.mustFix,
                  currentStatus: widget.step.poAction,
                  onPressed: () => _updateAction(PoActionStatus.mustFix),
                ),
                const SizedBox(height: 8),
                _ActionChip(
                  label: 'Backlog',
                  status: PoActionStatus.backlogTicket,
                  currentStatus: widget.step.poAction,
                  onPressed: () => _updateAction(PoActionStatus.backlogTicket),
                ),
                const SizedBox(height: 8),
                _ActionChip(
                  label: 'Parkeren',
                  status: PoActionStatus.geparkeerd,
                  currentStatus: widget.step.poAction,
                  onPressed: () => _updateAction(PoActionStatus.geparkeerd),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final PoActionStatus status;
  final PoActionStatus currentStatus;
  final VoidCallback onPressed;

  const _ActionChip({
    required this.label,
    required this.status,
    required this.currentStatus,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = currentStatus == status;
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: isSelected ? Theme.of(context).colorScheme.secondary : Colors.grey.shade200,
      labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
