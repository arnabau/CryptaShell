import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cryptashell/features/file_manager/presentation/bloc/file_manager_bloc.dart';
import 'package:cryptashell/features/file_manager/presentation/bloc/file_manager_state.dart';
import 'package:window_manager/window_manager.dart';

class FileManagerScreen extends StatefulWidget {
  final String? initialFile;
  final bool initialDecryptMode;

  const FileManagerScreen(
      {super.key, this.initialFile, this.initialDecryptMode = false});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  String _appVersion = '';
  bool _isEncryptMode = true;
  bool _isDragging = false;
  double _strengthValue = 0.0;
  Color _strengthColor = Colors.grey;
  bool _obscurePassword = true; // <-- show/hide password
  List<FileSystemEntity>?
      _preloadedElements; // pre-load if OS send a file using "Open with CryptaShell" menu option

  // toggle's options
  bool _deleteFileAfterProcess = false;
  bool _removeMetadataAfterProcess = false;

  static const intentChannel = MethodChannel('com.cryptashell/intent');

  @override
  void initState() {
    super.initState();

    intentChannel.setMethodCallHandler((call) async {
      if (call.method == 'onOpenFile') {
        _handleIncomingOSFile(call.arguments);
      }
    });

    _checkInitialOSFile();

    // If OS send a file using menu option...
    _isEncryptMode = !widget.initialDecryptMode;
    if (widget.initialFile != null && widget.initialFile!.isNotEmpty) {
      final path = widget.initialFile!;
      _preloadedElements = [
        FileSystemEntity.isDirectorySync(path) ? Directory(path) : File(path)
      ];
    }

    _loadAppVersion(); // <-- app name and version
  }

  Future<void> _checkInitialOSFile() async {
    try {
      final String? path = await intentChannel.invokeMethod('dartIsReady');

      if (path != null && path.isNotEmpty) {
        _handleIncomingOSFile(path);
      }
    } catch (e) {
      debugPrint("🛡️ Something went wrong: $e");
    }
  }

  void _handleIncomingOSFile(String path) {
    if (!mounted) return;

    setState(() {
      // pre load file
      _preloadedElements = [
        FileSystemEntity.isDirectorySync(path) ? Directory(path) : File(path)
      ];

      // if is a .crypta file --> Encrypt. If not --> Decrypt
      _isEncryptMode = !path.endsWith('.crypta');

      // clear UI
      _passwordController.clear();
      _confirmController.clear();
      _checkPasswordStrength('');
    });
  }

  Future<void> _loadAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      _appVersion = packageInfo.version;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await windowManager.setTitle('CryptaShell - v$_appVersion');
      await windowManager.setSize(const Size(450, 680));
      await windowManager.setMinimumSize(const Size(450, 680));
      await windowManager.setMaximumSize(const Size(600, 800));
    });
  }

  // Clean memory buffer and UI after any process
  void _resetToInitialState() {
    if (!mounted) return;

    setState(() {
      _preloadedElements = null;
      _passwordController.clear();
      _confirmController.clear();
      _strengthValue = 0.0;
      _strengthColor = Colors.grey;
      _isEncryptMode = true;
    });
  }

  void _onFileDropped(DropDoneDetails details) {
    if (details.files.isEmpty) return;

    final password = _passwordController.text;
    if (password.length < 8) {
      _showError('Enter a valid password before drop the file.');
      return;
    }
    if (_isEncryptMode && password != _confirmController.text) {
      _showError('The passwords do not match.');
      return;
    }

    if (!mounted) return;

    final passwordBytes = Uint8List.fromList(utf8.encode(password));

    if (_isEncryptMode) {
      final hasCrypta = details.files.any((f) => f.path.endsWith('.crypta'));

      if (hasCrypta) {
        _showError('One or more dropped files are already encrypted');
        return;
      }

      // 1. Dynamically classify whether they are files or folders
      final List<FileSystemEntity> elements = details.files.map((xFile) {
        return FileSystemEntity.isDirectorySync(xFile.path)
            ? Directory(xFile.path)
            : File(xFile.path);
      }).toList();

      // 2. Generate output name (macOS-style: Archive, Archive01, Archive02...)
      final parentDir = File(details.files.first.path).parent.path;
      final outputPath = _generatePath(parentDir, elements);

      context.read<FileManagerBloc>().add(
            EncryptRequested(
              elements: elements,
              passwordBytes: passwordBytes,
              removeMetadata: _removeMetadataAfterProcess,
              deleteSource: _deleteFileAfterProcess,
              outputPath: outputPath,
            ),
          );
    } else {
      final archivePath = details.files.first.path;
      if (!archivePath.endsWith('.crypta')) {
        _showError('I only work with .crypta files');
        return;
      }

      final archiveFile = File(archivePath);
      final outputDir = archiveFile.parent.path;

      context.read<FileManagerBloc>().add(
            DecryptRequested(
              archiveFile: archiveFile,
              passwordBytes: passwordBytes,
              deleteSource: _deleteFileAfterProcess,
              outputDir: outputDir,
            ),
          );
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // --- SECURITY LOGIC ---

  void _checkPasswordStrength(String pass) {
    if (pass.isEmpty) {
      setState(() {
        _strengthValue = 0.0;
        _strengthColor = Colors.grey;
      });
      return;
    }

    int score = 0;
    if (pass.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(pass)) score++; // Capital letters
    if (RegExp(r'[0-9]').hasMatch(pass)) score++; // Numbers
    if (RegExp(r'[!@#\$&*~_]').hasMatch(pass)) score++; // Symbols

    setState(() {
      _strengthValue = score / 4;
      if (score <= 1) {
        _strengthColor = Colors.redAccent;
      } else if (score == 2) {
        _strengthColor = Colors.orangeAccent;
      } else if (score == 3) {
        _strengthColor = Colors.yellowAccent;
      } else {
        _strengthColor = Colors.greenAccent;
      }
    });
  }

  void _generateSecurePassword() {
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890!@#\$%^&*()_+';
    final rnd = Random.secure();
    // Generates a cryptographically secure 16-character string
    final pass = String.fromCharCodes(
      Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );

    setState(() {
      _passwordController.text = pass;
      _confirmController.text = pass;
      _checkPasswordStrength(pass);
    });

    // Copy to clipboard automatically
    Clipboard.setData(ClipboardData(text: pass));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            '16-byte password generated and copied to the clipboard.'),
        backgroundColor: Colors.blueGrey.shade800,
      ),
    );
  }

  String _generatePath(String parentDir, List<FileSystemEntity> elements) {
    String baseName = 'Archive';

    // If it's a single item use its real name
    if (elements.length == 1) {
      final path = elements.first.path;
      baseName = path.split(Platform.pathSeparator).last.split('.').first;
    }

    const extension = '.crypta';
    String newPath = '$parentDir${Platform.pathSeparator}$baseName$extension';
    int counter = 2;

    // Avoid overwriting existing files
    while (File(newPath).existsSync()) {
      newPath =
          '$parentDir${Platform.pathSeparator}$baseName $counter$extension';
      counter++;
    }
    return newPath;
  }

  // --- MAIN LOGIC ---

  Future<void> _processFile() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      _showError('The password must be at least 8 characters long.');
      return;
    }
    if (_isEncryptMode && password != _confirmController.text) {
      _showError('The passwords do not match.');
      return;
    }

    final passwordBytes = Uint8List.fromList(utf8.encode(password));

    // --- PRELOADED FILE (WITHOUT PICKER/DROP) ---
    if (_preloadedElements != null && _preloadedElements!.isNotEmpty) {
      if (!mounted) return;

      if (_isEncryptMode) {
        final parentDir = File(_preloadedElements!.first.path).parent.path;
        final outputPath = _generatePath(parentDir, _preloadedElements!);

        context.read<FileManagerBloc>().add(
              EncryptRequested(
                elements: _preloadedElements!,
                passwordBytes: passwordBytes,
                removeMetadata: _removeMetadataAfterProcess,
                deleteSource: _deleteFileAfterProcess,
                outputPath: outputPath,
              ),
            );
      } else {
        final archiveFile = File(_preloadedElements!.first.path);
        final outputDir = archiveFile.parent.path;

        context.read<FileManagerBloc>().add(
              DecryptRequested(
                archiveFile: archiveFile,
                passwordBytes: passwordBytes,
                deleteSource: _deleteFileAfterProcess,
                outputDir: outputDir,
              ),
            );
      }
      return;
    }

    // --- IF THERE IS NO PRELOADED FILE, OPEN PICKER/DROP) ---
    FilePickerResult? result;

    if (_isEncryptMode) {
      result = await FilePicker.platform.pickFiles(allowMultiple: true);
    } else {
      result = await FilePicker.platform.pickFiles(
        type: Platform.isIOS ? FileType.any : FileType.custom,
        allowedExtensions: Platform.isIOS ? null : ['crypta'],
        allowMultiple: false,
      );
    }

    if (result != null && result.paths.isNotEmpty) {
      if (!mounted) return;

      if (_isEncryptMode) {
        final hasCrypta = result.paths
            .any((path) => path != null && path.endsWith('.crypta'));

        if (hasCrypta) {
          _showError('One or more selected files are already encrypted.');
          return;
        }

        final List<FileSystemEntity> elements =
            result.paths.map((p) => File(p!)).toList();
        final parentDir = File(result.paths.first!).parent.path;
        final outputPath = _generatePath(parentDir, elements);

        context.read<FileManagerBloc>().add(
              EncryptRequested(
                elements: elements,
                passwordBytes: passwordBytes,
                removeMetadata: _removeMetadataAfterProcess,
                deleteSource: _deleteFileAfterProcess,
                outputPath: outputPath,
              ),
            );
      } else {
        final archiveFile = File(result.files.single.path!);

        if (!archiveFile.path.endsWith('.crypta')) {
          _showError('Just .crypta files.');
          return;
        }

        final outputDir = archiveFile.parent.path;
        context.read<FileManagerBloc>().add(
              DecryptRequested(
                archiveFile: archiveFile,
                passwordBytes: passwordBytes,
                deleteSource: _deleteFileAfterProcess,
                outputDir: outputDir,
              ),
            );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: BlocConsumer<FileManagerBloc, FileManagerState>(
        listener: (context, state) async {
          if (state is FileManagerError) {
            _showError(state.message);
          } else if (state is FileManagerSuccess) {
            // Clean textfields
            _passwordController.clear();
            _confirmController.clear();
            setState(() {
              _strengthValue = 0.0;
            });

            // 2. iOS / Android
            if (Platform.isIOS || Platform.isAndroid) {
              // Closed the keyboard
              FocusScope.of(context).unfocus();

              // Open iOS/Android native window to save
              final xFiles = state.files.map((f) => XFile(f.path)).toList();
              await Share.shareXFiles(xFiles);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.isEncrypted
                      ? '🔒 Archive encrypted and saved successfully'
                      : '🔓 ${state.files.length} files extracted successfully'),
                  backgroundColor: Colors.greenAccent.shade700,
                  duration: const Duration(seconds: 4),
                ),
              );

              _resetToInitialState();
            }
          }
        },
        builder: (context, state) {
          return DropTarget(
              onDragEntered: (details) => setState(() => _isDragging = true),
              onDragExited: (details) => setState(() => _isDragging = false),
              onDragDone: (details) {
                setState(() => _isDragging = false);
                _onFileDropped(details);
              },
              child: Container(
                // "Hover" effect
                color: _isDragging
                    ? (_isEncryptMode
                        ? Colors.greenAccent.withValues(alpha: 0.05)
                        : Colors.orangeAccent.withValues(alpha: 0.05))
                    : Colors.transparent,

                // ---  ---
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40.0, vertical: 20.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        children: [
                          // ==========================================
                          // HEADER (Toggle)
                          // ==========================================
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ModeButton(
                                    title: 'ENCRYPT',
                                    isActive: _isEncryptMode,
                                    onTap: () {
                                      setState(() {
                                        _isEncryptMode = true;
                                        _passwordController.clear();
                                        _confirmController.clear();
                                        _checkPasswordStrength('');
                                      });
                                    },
                                  ),
                                  _ModeButton(
                                    title: 'DECRYPT',
                                    isActive: !_isEncryptMode,
                                    onTap: () {
                                      setState(() {
                                        _isEncryptMode = false;
                                        _passwordController.clear();
                                        _confirmController.clear();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ==========================================
                          // MAIN CONTENT
                          // ==========================================
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // dynamic icon
                                    Icon(
                                      _isEncryptMode
                                          ? Icons.lock_outline
                                          : Icons.lock_open_rounded,
                                      size: 100,
                                      color: state is FileManagerLoading
                                          ? Colors.blueAccent
                                          : (_isEncryptMode
                                              ? Colors.greenAccent
                                              : Colors.orangeAccent),
                                    ),
                                    Center(
                                      child: Text(
                                        "You can drop or select file(s) or folder(s)",
                                        style:
                                            TextStyle(color: Colors.grey[800]),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Main password field
                                    TextField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      onChanged: _checkPasswordStrength,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        labelStyle:
                                            const TextStyle(color: Colors.grey),
                                        enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade800)),
                                        focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: _isEncryptMode
                                                    ? Colors.greenAccent
                                                    : Colors.orangeAccent)),
                                        prefixIcon: const Icon(Icons.key,
                                            color: Colors.grey),
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_isEncryptMode)
                                              IconButton(
                                                icon: const Icon(Icons.casino,
                                                    color: Colors.greenAccent),
                                                tooltip:
                                                    'Generate a secure password',
                                                onPressed:
                                                    _generateSecurePassword,
                                              ),
                                            IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility
                                                    : Icons.visibility_off,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () => setState(() =>
                                                  _obscurePassword =
                                                      !_obscurePassword),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    if (_isEncryptMode) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: _strengthValue,
                                          backgroundColor: Colors.grey.shade900,
                                          color: _strengthColor,
                                          minHeight: 4,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Confirm pasword
                                      TextField(
                                        controller: _confirmController,
                                        obscureText: true,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        decoration: InputDecoration(
                                          labelText: 'Confirm Password',
                                          labelStyle: const TextStyle(
                                              color: Colors.grey),
                                          enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.grey.shade800)),
                                          focusedBorder:
                                              const OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.greenAccent)),
                                          prefixIcon: const Icon(
                                              Icons.check_circle_outline,
                                              color: Colors.grey),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 5),

                                    // Toggles
                                    ToggleDeleteFile(
                                      value: _deleteFileAfterProcess,
                                      isEncryptMode: _isEncryptMode,
                                      onChanged: (bool value) => setState(() =>
                                          _deleteFileAfterProcess = value),
                                    ),

                                    if (_isEncryptMode)
                                      ToggleRemoveMetaData(
                                        value: _removeMetadataAfterProcess,
                                        isEncryptMode: _isEncryptMode,
                                        onChanged: (bool value) => setState(
                                            () => _removeMetadataAfterProcess =
                                                value),
                                      ),

                                    const SizedBox(height: 40),

                                    // Main button
                                    SizedBox(
                                      height: 60,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _isEncryptMode
                                              ? Colors.greenAccent
                                                  .withValues(alpha: 0.1)
                                              : Colors.orangeAccent
                                                  .withValues(alpha: 0.1),
                                          foregroundColor: _isEncryptMode
                                              ? Colors.greenAccent
                                              : Colors.orangeAccent,
                                          side: BorderSide(
                                              color: _isEncryptMode
                                                  ? Colors.greenAccent
                                                  : Colors.orangeAccent),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                        onPressed: state is FileManagerLoading
                                            ? null
                                            : _processFile,
                                        icon: state is FileManagerLoading
                                            ? SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: _isEncryptMode
                                                            ? Colors.greenAccent
                                                            : Colors
                                                                .orangeAccent))
                                            : Icon(_isEncryptMode
                                                ? Icons.shield
                                                : Icons.lock_open),
                                        label: Text(
                                          state is FileManagerLoading
                                              ? 'WORKING...'
                                              : (_preloadedElements != null
                                                  ? (_isEncryptMode
                                                      ? 'ENCRYPT FILE'
                                                      : 'DECRYPT FILE')
                                                  : (_isEncryptMode
                                                      ? 'SELECT AND ENCRYPT'
                                                      : 'SELECT .CRYPTA FILE')),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ==========================================
                          // FOOTER
                          // ==========================================
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SocialLinks(
                                githubUrl: 'https://github.com/arnabau',
                                linkedinUrl:
                                    'https://linkedin.com/in/arnaldo-baumanis',
                              ),
                              quitButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ));
        },
      ),
    );
  }

  Widget quitButton() {
    return Tooltip(
      message: 'Close Application',
      child: IconButton(
        icon: const FaIcon(FontAwesomeIcons.x),
        color: Colors.white70,
        iconSize: 20.0,
        splashRadius: 24.0,
        hoverColor: Colors.greenAccent.withValues(alpha: 0.1),
        onPressed: () async {
          await windowManager.close();
        },
      ),
    );
  }
}

// helper widget
class _ModeButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton(
      {required this.title, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

// Screen for displaying social links
class SocialLinks extends StatelessWidget {
  final String githubUrl;
  final String linkedinUrl;

  const SocialLinks({
    super.key,
    required this.githubUrl,
    required this.linkedinUrl,
  });

  // Asynchronous function to open the browser securely
  Future<void> _launchUrl(String urlString, BuildContext context) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The link could not be opened.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // GitHub
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.github),
          color: Colors.white70,
          iconSize: 20.0,
          splashRadius: 24.0,
          hoverColor: Colors.greenAccent.withValues(alpha: 0.1),
          onPressed: () => _launchUrl(githubUrl, context),
        ),

        const SizedBox(width: 10),

        // LinkedIn
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.linkedin),
          color: Colors.white70,
          iconSize: 20.0,
          splashRadius: 24.0,
          hoverColor: Colors.blueAccent.withValues(alpha: 0.1),
          onPressed: () => _launchUrl(linkedinUrl, context),
        ),
      ],
    );
  }
}

// Options: Destroy the original file. If decrypting, destroy the .crypta container
class ToggleDeleteFile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isEncryptMode;

  const ToggleDeleteFile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isEncryptMode,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        isEncryptMode ? 'Destroy original file?' : 'Destroy .crypta container?',
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w200,
          fontSize: 15,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor:
          isEncryptMode ? Colors.greenAccent : Colors.orangeAccent,
      inactiveThumbColor: Colors.grey,
      inactiveTrackColor: Colors.grey[800],
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return isEncryptMode ? Colors.greenAccent : Colors.orangeAccent;
          }
          return Colors.transparent;
        },
      ),
    );
  }
}

class ToggleRemoveMetaData extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isEncryptMode;

  const ToggleRemoveMetaData({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isEncryptMode,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text(
        'Remove metadata?',
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w200,
          fontSize: 15,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor:
          isEncryptMode ? Colors.greenAccent : Colors.orangeAccent,
      inactiveThumbColor: Colors.grey,
      inactiveTrackColor: Colors.grey[800],
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return isEncryptMode ? Colors.greenAccent : Colors.orangeAccent;
          }
          return Colors.transparent;
        },
      ),
    );
  }
}
