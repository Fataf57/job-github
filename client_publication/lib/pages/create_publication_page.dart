import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/publication_service.dart';
import '../services/auth_service.dart';
import '../models/publication.dart';
import '../utils/constants.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kBg = Color(0xFFF0F4F8);
const _kCard = Colors.white;
const _kText = Color(0xFF1A1A2E);
const _kSubtext = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

class CreatePublicationPage extends StatefulWidget {
  final Publication? publication;
  const CreatePublicationPage({super.key, this.publication});

  @override
  State<CreatePublicationPage> createState() => _CreatePublicationPageState();
}

class _CreatePublicationPageState extends State<CreatePublicationPage> {
  final AuthService _authService = AuthService();
  final PublicationService _service = PublicationService();
  final GlobalKey<_FormBodyState> _formBodyKey = GlobalKey<_FormBodyState>();

  bool _isLoading = false;
  bool _isLoadingReferences = true;
  int? _auteurId;

  List<String> _sections = [];
  List<String> _sexeOptions = [];
  List<String> _localiteOptions = [];
  List<String> _domaineOptions = [];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadReferenceLists();
  }

  Future<void> _loadReferenceLists() async {
    try {
      final ref = await _service.fetchReferenceLists();
      if (!mounted) return;
      setState(() {
        _sections = ref.sections;
        _sexeOptions = ref.sexeOptions;
        _localiteOptions = ref.localites;
        _domaineOptions = ref.domaines;
        _isLoadingReferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sections = ['Professionnelle', 'Locale'];
        _sexeOptions = ['Tous', 'Homme', 'Femme'];
        _localiteOptions = ['OUAGA', 'BOBO', 'KOUDOU'];
        _domaineOptions = ['INFORMATIQUE', 'FINANCE COMPTABILITÉ', 'ELECTRICITÉ', 'ELECTRONIQUE', 'DROIT'];
        _isLoadingReferences = false;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    final user = await _authService.getCurrentUser();
    if (user != null && mounted) setState(() => _auteurId = user.id);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.publication != null;

    if (_isLoadingReferences) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: _buildAppBar(isEdit),
        body: const Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(isEdit),
      body: _FormBody(
        key: _formBodyKey,
        service: _service,
        auteurId: _auteurId,
        sections: _sections,
        sexeOptions: _sexeOptions,
        localiteOptions: _localiteOptions,
        domaineOptions: _domaineOptions,
        isSubmitting: _isLoading,
        onSubmitting: (v) => setState(() => _isLoading = v),
        publication: widget.publication,
      ),
      bottomNavigationBar: _buildPublishBar(isEdit),
    );
  }

  Widget _buildPublishBar(bool isEdit) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: _kCard,
          border: Border(top: BorderSide(color: _kBorder)),
          boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, -2))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
          onPressed: _isLoading ? null : () => _formBodyKey.currentState?.submit(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF1565C0),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isEdit ? Icons.save_outlined : Icons.publish_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isEdit ? 'Enregistrer' : 'Publier',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isEdit) {
    return AppBar(
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        isEdit ? 'Modifier la publication' : 'Nouvelle publication',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      centerTitle: true,
    );
  }
}

class _FormBody extends StatefulWidget {
  final PublicationService service;
  final int? auteurId;
  final List<String> sections;
  final List<String> sexeOptions;
  final List<String> localiteOptions;
  final List<String> domaineOptions;
  final bool isSubmitting;
  final ValueChanged<bool> onSubmitting;
  final Publication? publication;

  const _FormBody({
    super.key,
    required this.service,
    required this.auteurId,
    required this.sections,
    required this.sexeOptions,
    required this.localiteOptions,
    required this.domaineOptions,
    required this.isSubmitting,
    required this.onSubmitting,
    this.publication,
  });

  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  final _formKey = GlobalKey<FormState>();

  final _titreController = TextEditingController();
  final _contenuController = TextEditingController();
  final _telephonePostulerController = TextEditingController();
  final _emailPostulerController = TextEditingController();
  final _whatsappPostulerController = TextEditingController();
  final _depotPhysiquePostulerController = TextEditingController();

  late String _selectedSection;
  late String _selectedSexe;
  String? _selectedLocalite;
  List<String> _selectedDomaines = [];
  DateTime? _selectedDateLimite;
  List<File> _selectedImages = [];
  File? _selectedPdf;
  Uint8List? _selectedPdfBytes;
  String? _selectedPdfName;
  List<String> _existingImageUrls = [];
  String? _existingPdfUrl;

  @override
  void initState() {
    super.initState();
    final pub = widget.publication;
    if (pub != null) {
      _titreController.text = pub.titre;
      _contenuController.text = pub.contenuTexte;
      _telephonePostulerController.text = pub.telephonePostuler ?? '';
      _emailPostulerController.text = pub.emailPostuler ?? '';
      _whatsappPostulerController.text = pub.whatsappPostuler ?? '';
      _depotPhysiquePostulerController.text = pub.depotPhysiquePostuler ?? '';
      _selectedSection = pub.section.isNotEmpty
          ? pub.section
          : (widget.sections.isNotEmpty ? widget.sections.first : '');
      _selectedSexe = pub.sexe != null && pub.sexe!.isNotEmpty
          ? pub.sexe!
          : (widget.sexeOptions.isNotEmpty ? widget.sexeOptions.first : '');
      _selectedLocalite = pub.localite;
      _selectedDomaines = pub.domaines.toList();
      if (pub.dateLimite != null && pub.dateLimite!.isNotEmpty) {
        try {
          _selectedDateLimite = DateTime.parse(pub.dateLimite!);
        } catch (_) {}
      }
      if (pub.images.isNotEmpty) {
        _existingImageUrls = pub.images.map(_resolveUrl).where((u) => u.isNotEmpty).toList();
      } else if (pub.image != null && pub.image!.isNotEmpty) {
        _existingImageUrls = [_resolveUrl(pub.image!)];
      }
      if (pub.pdf != null && pub.pdf!.isNotEmpty) {
        _existingPdfUrl = _resolveUrl(pub.pdf!);
      }
    } else {
      _selectedSection = widget.sections.isNotEmpty ? widget.sections.first : '';
      _selectedSexe = widget.sexeOptions.isNotEmpty ? widget.sexeOptions.first : '';
    }
  }

  @override
  void dispose() {
    _titreController.dispose();
    _contenuController.dispose();
    _telephonePostulerController.dispose();
    _emailPostulerController.dispose();
    _whatsappPostulerController.dispose();
    _depotPhysiquePostulerController.dispose();
    super.dispose();
  }

  String _resolveUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '${Constants.baseUrl}$path';
    return '${Constants.baseUrl}/media/publications/$path';
  }

  InputDecoration _inputDec({required String label, IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: _kPrimary, size: 20) : null,
      filled: true,
      fillColor: _kCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }

  Widget _fieldGap() => const SizedBox(height: 10);

  Widget _formGroup({
    String? title,
    IconData? icon,
    Color? color,
    required List<Widget> fields,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null && icon != null && color != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Color.fromARGB((color.alpha * 0.12).round(), color.red, color.green, color.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) _fieldGap(),
            fields[i],
          ],
        ],
      ),
    );
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) return false;
    if (_selectedSection.isEmpty) {
      _showError('Veuillez choisir un type de publication');
      return false;
    }
    if (_selectedSection == 'Professionnelle' && _selectedDomaines.isEmpty) {
      _showError('Au moins un domaine est requis pour une publication professionnelle');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _selectedImages.addAll(images.map((x) => File(x.path))));
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final filePath = file.path;
      if (!kIsWeb && filePath != null) {
        setState(() {
          _selectedPdf = File(filePath);
          _selectedPdfBytes = null;
          _selectedPdfName = file.name;
        });
        return;
      }
      if (file.bytes != null) {
        setState(() {
          _selectedPdf = null;
          _selectedPdfBytes = file.bytes;
          _selectedPdfName = file.name;
        });
        return;
      }
      throw Exception('Impossible de lire le PDF sélectionné.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sélection PDF : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDateLimite() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateLimite ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedDateLimite != null
          ? TimeOfDay(hour: _selectedDateLimite!.hour, minute: _selectedDateLimite!.minute)
          : const TimeOfDay(hour: 23, minute: 59),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );

    setState(() {
      _selectedDateLimite = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? 23,
        pickedTime?.minute ?? 59,
        0,
      );
    });
  }

  void _showDomaineSelectionSheet() {
    final searchController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchController.text.toLowerCase();
            final available = widget.domaineOptions
                .where((d) => !_selectedDomaines.contains(d))
                .where((d) => query.isEmpty || d.toLowerCase().contains(query))
                .toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.65,
              decoration: const BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Ajouter un domaine',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kText),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: _kSubtext),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: _inputDec(label: 'Rechercher', icon: Icons.search, hint: 'Ex : informatique, droit…'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: available.isEmpty
                        ? Center(
                            child: Text(
                              query.isEmpty
                                  ? 'Tous les domaines sont déjà sélectionnés'
                                  : 'Aucun domaine trouvé',
                              style: const TextStyle(color: _kSubtext),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: available.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: _kBorder),
                            itemBuilder: (_, i) {
                              final d = available[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.work_outline, color: _kPrimary, size: 20),
                                title: Text(d, style: const TextStyle(fontWeight: FontWeight.w500, color: _kText)),
                                trailing: const Icon(Icons.add_circle_outline, color: _kPrimary, size: 22),
                                onTap: () {
                                  setState(() => _selectedDomaines.add(d));
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(searchController.dispose);
  }

  Future<void> submit() => _submit();

  Future<void> _submit() async {
    if (!_validateForm()) return;

    if (widget.auteurId == null) {
      _showError('Vous devez être connecté pour publier');
      return;
    }

    widget.onSubmitting(true);
    try {
      final dateLimiteStr = _selectedDateLimite != null
          ? DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(_selectedDateLimite!)
          : null;
      final imagePaths = _selectedImages.map((f) => f.path).toList();
      final isEdit = widget.publication != null && widget.publication!.id != null;
      Publication? result;

      if (isEdit) {
        result = await widget.service.updatePublication(
          id: widget.publication!.id!,
          titre: _titreController.text.trim(),
          contenuTexte: _contenuController.text.trim(),
          section: _selectedSection,
          domaines: _selectedDomaines,
          localite: _selectedLocalite,
          sexe: _selectedSexe,
          dateLimite: dateLimiteStr,
          imagesPaths: imagePaths.isNotEmpty ? imagePaths : null,
          pdfPath: _selectedPdf?.path,
          pdfBytes: _selectedPdfBytes,
          pdfFilename: _selectedPdfName,
          telephonePostuler: _telephonePostulerController.text.trim().isNotEmpty
              ? _telephonePostulerController.text.trim()
              : null,
          emailPostuler: _emailPostulerController.text.trim().isNotEmpty
              ? _emailPostulerController.text.trim()
              : null,
          whatsappPostuler: _whatsappPostulerController.text.trim().isNotEmpty
              ? _whatsappPostulerController.text.trim()
              : null,
          depotPhysiquePostuler: _depotPhysiquePostulerController.text.trim().isNotEmpty
              ? _depotPhysiquePostulerController.text.trim()
              : null,
        );
      } else {
        result = await widget.service.createPublication(
          titre: _titreController.text.trim(),
          contenuTexte: _contenuController.text.trim(),
          auteurId: widget.auteurId!,
          section: _selectedSection,
          domaines: _selectedDomaines,
          localite: _selectedLocalite,
          sexe: _selectedSexe,
          dateLimite: dateLimiteStr,
          imagesPaths: imagePaths,
          pdfPath: _selectedPdf?.path,
          pdfBytes: _selectedPdfBytes,
          pdfFilename: _selectedPdfName,
          telephonePostuler: _telephonePostulerController.text.trim().isNotEmpty
              ? _telephonePostulerController.text.trim()
              : null,
          emailPostuler: _emailPostulerController.text.trim().isNotEmpty
              ? _emailPostulerController.text.trim()
              : null,
          whatsappPostuler: _whatsappPostulerController.text.trim().isNotEmpty
              ? _whatsappPostulerController.text.trim()
              : null,
          depotPhysiquePostuler: _depotPhysiquePostulerController.text.trim().isNotEmpty
              ? _depotPhysiquePostulerController.text.trim()
              : null,
        );
      }

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEdit ? 'Publication modifiée avec succès !' : 'Publication créée avec succès !'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        var msg = e.toString();
        if (msg.startsWith('Exception: ')) msg = msg.substring(11);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'Fermer', textColor: Colors.white, onPressed: () {}),
        ));
      }
    } finally {
      if (mounted) widget.onSubmitting(false);
    }
  }

  Widget _domainesField() {
    final domainesRequired = _selectedSection == 'Professionnelle';
    return InkWell(
      onTap: widget.domaineOptions.isEmpty ? null : _showDomaineSelectionSheet,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _inputDec(
          label: domainesRequired ? 'Domaines *' : 'Domaines',
          icon: Icons.work_outline,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedDomaines.isEmpty ? 'Appuyez pour sélectionner' : _selectedDomaines.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _selectedDomaines.isEmpty ? _kSubtext : _kText,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: _kSubtext, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _dateLimiteField() {
    return InkWell(
      onTap: _selectDateLimite,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _inputDec(label: 'Date limite', icon: Icons.calendar_today_outlined),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedDateLimite != null
                    ? DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateLimite!)
                    : 'Optionnel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _selectedDateLimite != null ? _kText : _kSubtext,
                  fontSize: 14,
                ),
              ),
            ),
            if (_selectedDateLimite != null)
              GestureDetector(
                onTap: () => setState(() => _selectedDateLimite = null),
                child: const Icon(Icons.close, size: 18, color: _kSubtext),
              ),
          ],
        ),
      ),
    );
  }

  void _showMediaTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Joindre un fichier',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: _kPrimary),
              title: const Text('Photos'),
              trailing: const Icon(Icons.chevron_right, color: _kSubtext, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages();
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: _kBorder),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFDC2626)),
              title: const Text('Document PDF'),
              trailing: const Icon(Icons.chevron_right, color: _kSubtext, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                _pickPdf();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _mediasSummary() {
    final photoCount = _existingImageUrls.length + _selectedImages.length;
    final hasPdf = _existingPdfUrl != null || _selectedPdf != null || _selectedPdfBytes != null;
    final parts = <String>[];
    if (photoCount > 0) parts.add('$photoCount photo${photoCount > 1 ? 's' : ''}');
    if (hasPdf) {
      final name = _selectedPdfName ??
          _selectedPdf?.path.split('/').last ??
          _existingPdfUrl?.split('/').last;
      parts.add(name ?? 'PDF');
    }
    return parts.join(' · ');
  }

  Widget _mediasField() {
    final summary = _mediasSummary();
    return InkWell(
      onTap: _showMediaTypePicker,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _inputDec(label: 'Fichier', icon: Icons.attach_file_outlined),
        child: Row(
          children: [
            Expanded(
              child: Text(
                summary.isEmpty ? 'Appuyez pour joindre un fichier' : summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: summary.isEmpty ? _kSubtext : _kText,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.add_circle_outline, color: _kPrimary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _pdfPreviewRow() {
    final name = _selectedPdfName ??
        _selectedPdf?.path.split('/').last ??
        _existingPdfUrl?.split('/').last ??
        'document.pdf';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _kText),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _existingPdfUrl = null;
              _selectedPdf = null;
              _selectedPdfBytes = null;
              _selectedPdfName = null;
            }),
            child: const Icon(Icons.close, size: 18, color: _kSubtext),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview({
    required List<dynamic> items,
    required void Function(int) onRemove,
  }) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final item = items[i];
          final isNetwork = item is String;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isNetwork
                    ? Image.network(
                        item,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Icons.broken_image, color: Color(0xFF9CA3AF), size: 22),
                        ),
                      )
                    : Image.file(item as File, width: 64, height: 64, fit: BoxFit.cover),
              ),
              if (i == 0)
                Positioned(
                  bottom: 2,
                  left: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xD91565C0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 8)),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = _existingImageUrls.isNotEmpty || _selectedImages.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                  _formGroup(
                    fields: [
                      DropdownButtonFormField<String>(
                        value: _selectedSection.isEmpty ? null : _selectedSection,
                        decoration: _inputDec(label: 'Section *', icon: Icons.category_outlined),
                        items: widget.sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _selectedSection = v!),
                      ),
                      TextFormField(
                        controller: _titreController,
                        decoration: _inputDec(
                          label: 'Titre *',
                          icon: Icons.title,
                          hint: 'Ex : Offre de stage en informatique',
                        ),
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[],
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Le titre est requis' : null,
                      ),
                      TextFormField(
                        controller: _contenuController,
                        decoration: _inputDec(
                          label: 'Description',
                          icon: Icons.description_outlined,
                          hint: 'Décrivez le poste, les exigences, la rémunération…',
                        ),
                        maxLines: 1,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[],
                      ),
                    ],
                  ),
                  _formGroup(
                    fields: [
                      _domainesField(),
                      DropdownButtonFormField<String>(
                        value: _selectedLocalite,
                        decoration: _inputDec(label: 'Ville', icon: Icons.location_on_outlined),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Toutes les villes')),
                          ...widget.localiteOptions.map((l) => DropdownMenuItem(value: l, child: Text(l))),
                        ],
                        onChanged: (v) => setState(() => _selectedLocalite = v),
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedSexe.isEmpty ? null : _selectedSexe,
                        decoration: _inputDec(label: 'Genre concerné *', icon: Icons.wc_outlined),
                        items: widget.sexeOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                        onChanged: (v) => setState(() => _selectedSexe = v!),
                      ),
                      _dateLimiteField(),
                    ],
                  ),
                  _formGroup(
                    title: 'Moyens de postuler',
                    icon: Icons.send_outlined,
                    color: const Color(0xFF059669),
                    fields: [
                      TextFormField(
                        controller: _telephonePostulerController,
                        decoration: _inputDec(
                          label: 'Téléphone',
                          icon: Icons.phone,
                          hint: '+226 XX XX XX XX',
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[],
                      ),
                      TextFormField(
                        controller: _emailPostulerController,
                        decoration: _inputDec(
                          label: 'Email',
                          icon: Icons.email_outlined,
                          hint: 'contact@exemple.com',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[],
                      ),
                      TextFormField(
                        controller: _whatsappPostulerController,
                        decoration: _inputDec(
                          label: 'WhatsApp',
                          icon: Icons.chat_outlined,
                          hint: 'https://wa.me/226XXXXXXXX',
                        ),
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[],
                      ),
                      TextFormField(
                        controller: _depotPhysiquePostulerController,
                        decoration: _inputDec(
                          label: 'Dépôt physique',
                          icon: Icons.location_on_outlined,
                          hint: 'Adresse complète du lieu de dépôt',
                        ),
                        maxLines: 1,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[],
                      ),
                    ],
                  ),
                  _formGroup(
                    fields: [
                      _mediasField(),
                      if (hasPhotos)
                        _buildImagePreview(
                          items: [..._existingImageUrls, ..._selectedImages],
                          onRemove: (i) => setState(() {
                            if (i < _existingImageUrls.length) {
                              _existingImageUrls.removeAt(i);
                            } else {
                              _selectedImages.removeAt(i - _existingImageUrls.length);
                            }
                          }),
                        ),
                      if (_existingPdfUrl != null || _selectedPdf != null || _selectedPdfBytes != null)
                        _pdfPreviewRow(),
                    ],
                  ),
                ],
              ),
            ),
          );
  }
}
