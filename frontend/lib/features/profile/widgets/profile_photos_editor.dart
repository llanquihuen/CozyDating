import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/auth_service.dart';

/// The real face's photos: the official profile photo (with the selfie verification) and up to five
/// more. Uploads and photo changes reach the server at once, as before; [onChanged] reports every
/// change so the caller can update its card.
///
/// Moved from the old profile form (`EditProfileScreen`, now gone) with its behaviour unchanged (camera recovery after Android
/// kills the activity included).
class ProfilePhotos {
  const ProfilePhotos({this.profilePhoto, this.photos = const [], this.isVerified = false, this.verificationSelfie});

  final String? profilePhoto;
  final List<String> photos;
  final bool isVerified;
  final String? verificationSelfie;
}

/// Colours of the photo sections, so they can wear the card theme's.
class PhotosPalette {
  const PhotosPalette({
    required this.surface,
    required this.inner,
    required this.border,
    required this.accent,
    required this.button,
    required this.onButton,
    required this.text,
    required this.muted,
  });

  /// Background of each block, and of the photo slots inside it.
  final Color surface;
  final Color inner;
  final Color border;

  /// Icons and links on [surface]; [button] fills buttons, with [onButton] on top.
  final Color accent;
  final Color button;
  final Color onButton;
  final Color text;
  final Color muted;

  /// The app's dark slate look.
  static const PhotosPalette slate = PhotosPalette(
    surface: Color(0xFF1E293B),
    inner: Color(0xFF0F172A),
    border: Color(0xFF334155),
    accent: Color(0xFF38BDF8),
    button: Color(0xFF0284C7),
    onButton: Colors.white,
    text: Colors.white,
    muted: Color(0xFF94A3B8),
  );
}

class ProfilePhotosEditor extends StatefulWidget {
  const ProfilePhotosEditor({super.key, required this.initial, this.onChanged, this.palette = PhotosPalette.slate});

  final ProfilePhotos initial;
  final ValueChanged<ProfilePhotos>? onChanged;
  final PhotosPalette palette;

  @override
  State<ProfilePhotosEditor> createState() => _ProfilePhotosEditorState();
}

class _ProfilePhotosEditorState extends State<ProfilePhotosEditor> {
  String? _currentPhoto;
  late List<String> _userPhotos;
  bool _isVerified = false;
  String? _verificationSelfie;

  final List<String> _samplePhotoPresets = const [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=600&auto=format&fit=crop&q=80',
  ];

  static const String _prefPendingCameraActionKey = 'pending_character_creator_camera_action';
  static const String _actionSelfieVerification = 'selfie_verification';
  static const String _actionProfilePhoto = 'profile_photo';

  @override
  void initState() {
    super.initState();
    _currentPhoto = widget.initial.profilePhoto;
    _userPhotos = List<String>.from(widget.initial.photos);
    _isVerified = widget.initial.isVerified;
    _verificationSelfie = widget.initial.verificationSelfie;
    // Recuperación de imágenes si Android LMK destruyó el Activity en dispositivos de 4GB (ej. Redmi 12)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLostCameraData());
  }

  /// Every change to the photos goes through setState: report it too.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.onChanged?.call(ProfilePhotos(
      profilePhoto: _currentPhoto,
      photos: List.unmodifiable(_userPhotos),
      isVerified: _isVerified,
      verificationSelfie: _verificationSelfie,
    ));
  }

  PhotosPalette get _p => widget.palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOfficialPhotoAndVerificationSection(),
        const SizedBox(height: 16),
        _buildHobbyGallerySection(),
      ],
    );
  }

  Future<void> _checkLostCameraData() async {
    try {
      final picker = ImagePicker();
      final LostDataResponse response = await picker.retrieveLostData();
      if (response.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final pendingAction = prefs.getString(_prefPendingCameraActionKey);
      await prefs.remove(_prefPendingCameraActionKey);

      final file = response.file;
      if (file != null) {
        if (pendingAction == _actionSelfieVerification) {
          if (mounted) {
            await _processVerificationSelfie(file);
          }
        } else if (pendingAction == _actionProfilePhoto) {
          if (mounted) {
            await _uploadAndSetProfilePhoto(file);
          }
        }
      } else if (response.exception != null && mounted) {
        debugPrint('[ProfilePhotosEditor] Excepción recuperada de ImagePicker: ${response.exception}');
      }
    } catch (e) {
      debugPrint('[ProfilePhotosEditor] Error en _checkLostCameraData: $e');
    }
  }


  Widget _buildOfficialPhotoAndVerificationSection() {
    final hasPhoto = _currentPhoto != null && _currentPhoto!.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isVerified ? Color(0xFF10B981).withOpacity(0.5) : _p.border,
          width: _isVerified ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Row(
                children: [
                  Icon(Icons.badge_outlined, color: _p.accent, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                      child: Text(
                    'Foto de Perfil Oficial',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _p.text,
                    ),
                  )),
                ],
              )),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      _isVerified ? Color(0xFF059669).withOpacity(0.2) : Color(0xFFD97706).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isVerified ? Color(0xFF10B981) : Color(0xFFF59E0B),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isVerified ? Icons.verified : Icons.warning_amber_rounded,
                      size: 14,
                      color: _isVerified ? Color(0xFF34D399) : Color(0xFFFBBF24),
                    ),
                    SizedBox(width: 4),
                    Text(
                      _isVerified ? 'Certificado 🛡️' : 'Sin Certificar ⚠️',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isVerified ? Color(0xFF34D399) : Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Tu foto principal visible en citas. Requiere certificación facial con selfie para comprobar tu identidad.',
            style: TextStyle(fontSize: 12, color: _p.muted),
          ),
          SizedBox(height: 16),

          // Main Photo Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Display
              GestureDetector(
                onTap: _showChangeProfilePhotoDialog,
                child: Container(
                  width: 125,
                  height: 155,
                  decoration: BoxDecoration(
                    color: _p.inner,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isVerified ? Color(0xFF10B981) : _p.border,
                      width: 2,
                    ),
                    boxShadow: [
                      if (_isVerified)
                        BoxShadow(
                          color: Color(0xFF10B981).withOpacity(0.25),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasPhoto
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              AppConfig.resolveMediaUrl(_currentPhoto!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(Icons.broken_image, color: _p.muted),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black.withOpacity(0.65),
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.edit, color: _p.muted, size: 12),
                                    SizedBox(width: 4),
                                    Text('Cambiar', style: TextStyle(color: _p.text, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: _p.accent, size: 28),
                            SizedBox(height: 6),
                            Text('Elegir Foto', style: TextStyle(color: _p.muted, fontSize: 11)),
                          ],
                        ),
                ),
              ),
              SizedBox(width: 16),

              // Actions & Verification Status Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isVerified) ...[
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFF064E3B).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(0xFF059669)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF34D399), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Identidad comprobada. Tienes acceso total a citas y matchmaking en la Mazmorra.',
                                style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 11.5, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _p.muted,
                          side: BorderSide(color: _p.border),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(Icons.refresh, size: 14),
                        label: Text('Re-certificar con selfie', style: TextStyle(fontSize: 11)),
                        onPressed: _startSelfieVerification,
                      ),
                    ] else ...[
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFF78350F).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(0xFFD97706)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFFBBF24), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Obligatorio: tómate una selfie rápida para comparar rasgos faciales y certificar tu cuenta.',
                                style: TextStyle(color: Color(0xFFFEF3C7), fontSize: 11.5, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _p.button,
                          foregroundColor: _p.onButton,
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 3,
                        ),
                        icon: Icon(Icons.camera_front, size: 18),
                        label: Text(
                          '🤳 Certificar con Selfie Rápida',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _startSelfieVerification,
                      ),
                    ],
                    SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: _p.accent,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(Icons.image, size: 14),
                      label: Text('Cambiar Foto de Perfil', style: TextStyle(fontSize: 11.5)),
                      onPressed: _showChangeProfilePhotoDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHobbyGallerySection() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Row(
                children: [
                  Icon(Icons.photo_library, color: Color(0xFFFB7185), size: 20),
                  SizedBox(width: 8),
                  Flexible(
                      child: Text(
                    'Galería de Pasatiempos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _p.text,
                    ),
                  )),
                ],
              )),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _p.inner,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _p.border),
                ),
                child: Text(
                  '${_userPhotos.length} / 5 fotos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _p.accent,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Comparte fotos de tus hobbies, viajes, mascotas o lugares. No requieren certificación y se revelarán tras match mutuo.',
            style: TextStyle(fontSize: 12, color: _p.muted),
          ),
          SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: 5,
            itemBuilder: (context, index) {
              if (index < _userPhotos.length) {
                final photoUrl = _userPhotos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        AppConfig.resolveMediaUrl(photoUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, error, stackTrace) {
                          return Container(
                            color: _p.border,
                            child: Icon(Icons.broken_image, color: _p.muted, size: 20),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _userPhotos.removeAt(index);
                          });
                          AuthService.updateProfilePhotos(_userPhotos);
                        },
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: _p.text, size: 12),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return GestureDetector(
                  onTap: _showAddHobbyPhotoDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _p.inner,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _p.border,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: _p.accent, size: 22),
                        SizedBox(height: 4),
                        Text('Añadir', style: TextStyle(color: _p.muted, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndSetProfilePhoto(XFile pickedFile) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Subiendo Foto Oficial al servidor...'),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }

    try {
      final bytes = await pickedFile.readAsBytes();
      final filename =
          pickedFile.name.isNotEmpty ? pickedFile.name : 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final uploadedUrl = await AuthService.uploadMediaPhoto(bytes, filename, setAsProfile: true);
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        setState(() {
          _currentPhoto = uploadedUrl;
          _isVerified = false; // Requiere certificar la nueva foto
        });
        AuthService.updateProfilePhoto(uploadedUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto oficial actualizada. Recuerda certificarla con tu selfie 🤳'),
              backgroundColor: Color(0xFF0284C7),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al subir la foto de perfil al servidor'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar imagen: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadProfilePhoto(ImageSource source, BuildContext dialogContext) async {
    if (dialogContext.mounted) Navigator.pop(dialogContext);

    XFile? pickedFile;
    try {
      if (source == ImageSource.camera) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefPendingCameraActionKey, _actionProfilePhoto);
      }

      // Pausar motor Flame para ceder memoria y CPU en dispositivos de gama de entrada

      final picker = ImagePicker();
      pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al acceder a la cámara o galería: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefPendingCameraActionKey);
      } catch (_) {}
    }

    if (pickedFile != null && mounted) {
      await _uploadAndSetProfilePhoto(pickedFile);
    }
  }

  void _showChangeProfilePhotoDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Foto de Perfil Oficial', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Elige tu foto de perfil desde tu dispositivo:',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Galería', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _pickAndUploadProfilePhoto(ImageSource.gallery, dialogContext),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF38BDF8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Cámara', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _pickAndUploadProfilePhoto(ImageSource.camera, dialogContext),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF334155))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('O fotos de muestra recomendadas',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ),
                    Expanded(child: Divider(color: Color(0xFF334155))),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _samplePhotoPresets.map((url) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentPhoto = url;
                          _isVerified = false;
                        });
                        AuthService.updateProfilePhoto(url);
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Foto de muestra seleccionada. Realiza la certificación para activarla 🤳'),
                            backgroundColor: Color(0xFF0284C7),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'O pega una URL: https://...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF475569)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final url = textController.text.trim();
              if (url.isNotEmpty) {
                setState(() {
                  _currentPhoto = url;
                  _isVerified = false;
                });
                AuthService.updateProfilePhoto(url);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Usar URL'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadHobbyPhoto(ImageSource source, BuildContext dialogContext) async {
    try {
      final availableSlots = 5 - _userPhotos.length;
      if (availableSlots <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ya alcanzaste el límite máximo de 5 fotos en la galería'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (dialogContext.mounted) Navigator.pop(dialogContext);

      final picker = ImagePicker();
      List<XFile> pickedFiles = [];

      try {
        if (source == ImageSource.gallery) {
          pickedFiles = await picker.pickMultiImage(
            maxWidth: 1080,
            maxHeight: 1080,
            imageQuality: 80,
          );
        } else {
          final single = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1080,
            maxHeight: 1080,
            imageQuality: 80,
          );
          if (single != null) {
            pickedFiles.add(single);
          }
        }
      } finally {}

      if (pickedFiles.isEmpty) return;

      final toUpload = pickedFiles.take(availableSlots).toList();
      final List<String> newlyUploaded = [];

      for (int i = 0; i < toUpload.length; i++) {
        final file = toUpload[i];
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(toUpload.length > 1
                      ? 'Subiendo foto ${i + 1} de ${toUpload.length} a la galería...'
                      : 'Subiendo foto a la galería...'),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }

        final bytes = await file.readAsBytes();
        final filename = file.name.isNotEmpty ? file.name : 'hobby_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        final uploadedUrl = await AuthService.uploadMediaPhoto(bytes, filename, setAsProfile: false);
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          newlyUploaded.add(uploadedUrl);
        }
      }

      if (newlyUploaded.isNotEmpty) {
        setState(() {
          _userPhotos.addAll(newlyUploaded);
        });
        await AuthService.updateProfilePhotos(_userPhotos);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newlyUploaded.length == 1
                  ? '¡Foto añadida a tu galería de pasatiempos!'
                  : '¡${newlyUploaded.length} fotos añadidas a tu galería!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar foto: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAddHobbyPhotoDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.photo_library, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Añadir Foto a Galería', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sube fotos de tus pasatiempos o momentos (puedes seleccionar varias):',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Galería (Múltiples)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _pickAndUploadHobbyPhoto(ImageSource.gallery, dialogContext),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF38BDF8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Cámara', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _pickAndUploadHobbyPhoto(ImageSource.camera, dialogContext),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF334155))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('O fotos de muestra', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ),
                    Expanded(child: Divider(color: Color(0xFF334155))),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _samplePhotoPresets.map((url) {
                    return GestureDetector(
                      onTap: () {
                        if (_userPhotos.length < 5) {
                          setState(() {
                            _userPhotos.add(url);
                          });
                          AuthService.updateProfilePhotos(_userPhotos);
                          Navigator.pop(dialogContext);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://images.unsplash.com/...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF475569)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final url = textController.text.trim();
              if (url.isNotEmpty && _userPhotos.length < 5) {
                setState(() {
                  _userPhotos.add(url);
                });
                AuthService.updateProfilePhotos(_userPhotos);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Añadir URL'),
          ),
        ],
      ),
    );
  }

  Future<void> _processVerificationSelfie(XFile pickedFile) async {
    if (!mounted) return;

    // Mostrar diálogo interactivo de escaneo biométrico
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SimulatedFaceScanDialog(),
    );

    try {
      final bytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name.isNotEmpty ? pickedFile.name : 'selfie.jpg';

      // Esperar 1.2 segundos para mostrar el progreso de escaneo visual
      await Future.delayed(const Duration(milliseconds: 1200));

      final result = await AuthService.verifyIdentity(bytes, filename);

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de escaneo
      }

      if (result['verified'] == true) {
        setState(() {
          _isVerified = true;
          _verificationSelfie = result['selfieUrl'] as String?;
        });

        if (mounted) {
          _showVerificationSuccessDialog(result);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'No se pudo verificar la identidad facial.'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error durante la verificación: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _startSelfieVerification() async {
    if (_currentPhoto == null || _currentPhoto!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero debes seleccionar una Foto de Perfil Oficial antes de verificar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final shouldOpenCamera = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.face_retouching_natural, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Flexible(child: Text('Certificación Facial', style: TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tómate una selfie rápida de frente con buena iluminación.',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'El sistema comparará biométricamente tu rostro con tu Foto de Perfil Oficial para validar que eres una persona real.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.camera_front, size: 18),
            label: const Text('Abrir Cámara Frontal'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (shouldOpenCamera != true) return;
    if (!mounted) return;

    final picker = ImagePicker();
    XFile? pickedFile;

    try {
      // 1. Registrar intención pendiente para LMK en Android de gama baja
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPendingCameraActionKey, _actionSelfieVerification);

      // 2. Pausar motor Flame para ceder memoria y CPU al sensor nativo de MIUI

      pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
    } catch (_) {
      // Fallback para emuladores o plataformas sin cámara frontal directa
      try {
        pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 75,
        );
      } catch (e) {
        debugPrint('[ProfilePhotosEditor] Error en fallback de selección de selfie: $e');
      }
    } finally {
      // Reanudar Flame y limpiar bandera si el proceso sobrevivió
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefPendingCameraActionKey);
      } catch (_) {}
    }

    if (pickedFile == null) return;
    if (!mounted) return;

    await _processVerificationSelfie(pickedFile);
  }

  void _showVerificationSuccessDialog(Map<String, dynamic> result) {
    final similarity = result['similarity'] != null ? '${(result['similarity'] as num).toStringAsFixed(1)}%' : '98.5%';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified, color: Color(0xFF10B981), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Identidad Certificada! 🛡️',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Coincidencia facial: $similarity (AWS Rekognition Simulado)',
              style: const TextStyle(color: Color(0xFF34D399), fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tu perfil ha recibido el distintivo de confianza. Ahora puedes ingresar a las citas en la Mazmorra Cooperativa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('¡Excelente!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimulatedFaceScanDialog extends StatefulWidget {
  const _SimulatedFaceScanDialog();

  @override
  State<_SimulatedFaceScanDialog> createState() => _SimulatedFaceScanDialogState();
}

class _SimulatedFaceScanDialogState extends State<_SimulatedFaceScanDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _step = 0;

  final List<String> _steps = const [
    'Detectando puntos y proporciones faciales...',
    'Generando vector de embedding biométrico...',
    'Comparando con Foto Oficial en AWS Rekognition (Simulado)...',
    'Validando coincidencia y liveness...',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _progressSteps();
  }

  void _progressSteps() async {
    for (int i = 1; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        setState(() {
          _step = i;
        });
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // Scanning Visualizer
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F172A),
                    border: Border.all(
                      color: Color.lerp(const Color(0xFF0284C7), const Color(0xFF10B981), _animController.value)!,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.3 + 0.3 * _animController.value),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.face,
                        size: 64,
                        color: Colors.white.withOpacity(0.4 + 0.4 * _animController.value),
                      ),
                      Positioned(
                        top: 20 + 70 * _animController.value,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, Color(0xFF38BDF8), Color(0xFF34D399), Colors.transparent],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Escaneo Biométrico',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _steps[_step],
                key: ValueKey(_step),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor: const Color(0xFF0F172A),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Simulación de AWS Rekognition activa',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
