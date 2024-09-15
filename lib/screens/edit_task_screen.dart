import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/utils/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class EditTaskScreen extends ConsumerStatefulWidget {
  final int taskId;

  const EditTaskScreen({
    super.key,
    required this.taskId,
  });

  @override
  // ignore: library_private_types_in_public_api
  _EditTaskScreenState createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends ConsumerState<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  DateTime? _dueDate;
  late int _priority;
  String? _notes;
  List<String> _attachments = [];
  bool _attachmentsExpanded = true; // Controls the collapse state
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator =
      true; // Controls visibility of the scroll indicator

  @override
  void initState() {
    super.initState();
    final task = ref.read(taskProvider).maybeWhen(
          data: (tasks) => tasks.firstWhere((task) => task.id == widget.taskId),
          orElse: () => null,
        );

    if (task != null) {
      _title = task.title;
      _dueDate = task.dueDate;
      _priority = task.priority;
      _notes = task.notes;
      // Filter out null or empty paths correctly
      _attachments = [
        ...task.filePaths.where((path) => path.isNotEmpty),
        ...task.imagePaths.where((path) => path.isNotEmpty)
      ];
    }

    _scrollController.addListener(() {
      if (_scrollController.position.atEdge) {
        if (_scrollController.position.pixels != 0) {
          // If at the end of the scroll, hide the arrow
          setState(() {
            _showScrollIndicator = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _submitTask() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final updatedTask = Task(
        id: widget.taskId,
        title: _title,
        dueDate: _dueDate!,
        priority: _priority,
        notes: _notes,
        filePaths: _attachments
            .where((attachment) => !_isImage(attachment))
            .where((path) => path.isNotEmpty)
            .toList(),
        imagePaths: _attachments
            .where((attachment) => _isImage(attachment))
            .where((path) => path.isNotEmpty)
            .toList(),
      );
      ref.read(taskProvider.notifier).updateTask(updatedTask);
      Navigator.of(context).pop();
    }
  }

  void _pickDueDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              onPrimary: Colors.black,
              surface: cardColor,
              onSurface: textColor,
            ),
            dialogBackgroundColor: defaultBackgroundColor,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        // ignore: use_build_context_synchronously
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dueDate ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: accentColor,
                onPrimary: Colors.black,
                surface: cardColor,
                onSurface: textColor,
              ),
              dialogBackgroundColor: defaultBackgroundColor,
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.image, color: accentColor),
              title: Text('Gallery', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_file, color: accentColor),
              title: Text('File', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        );
      },
    );
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _attachments.add(result.files.single.path!);
        _showScrollIndicator =
            true; // Reset scroll indicator when adding new attachments
      });
    }
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _attachments.add(pickedFile.path);
        _showScrollIndicator =
            true; // Reset scroll indicator when adding new attachments
      });
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  bool _isImage(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif'].contains(extension);
  }

  String _truncateFileName(String fileName, [int maxLength = 15]) {
    if (fileName.length <= maxLength) return fileName;
    return '${fileName.substring(0, maxLength)}...';
  }

  Widget _buildAttachmentPreviews() {
    // Calculate whether scrolling is necessary
    bool needsScrolling =
        _attachments.length > 4; // Adjust this threshold based on item size

    return Stack(
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _attachmentsExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: SizedBox(
            height: 102, // Increased height slightly to avoid overflow
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _attachments.length,
              itemBuilder: (context, index) {
                final attachment = _attachments[index];
                final isImage = _isImage(attachment);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          SizedBox(
                            width: 70,
                            height: 70,
                            child: isImage
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.file(File(attachment),
                                        fit: BoxFit.cover),
                                  )
                                : Icon(Icons.insert_drive_file,
                                    size: 50, color: accentColor),
                          ),
                          const SizedBox(height: 2), // Reduced spacing
                          SizedBox(
                            width: 70,
                            child: Text(
                              _truncateFileName(path.basename(attachment)),
                              style: TextStyle(color: textColor, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removeAttachment(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          secondChild: Container(),
        ),
        if (_showScrollIndicator &&
            needsScrolling) // Show indicator only if there is hidden content
          Positioned(
            right: 0,
            top: 35, // Center vertically on the attachment preview
            child: Icon(Icons.arrow_forward_ios,
                color: Colors.grey.withOpacity(0.5)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);

    return taskState.when(
      data: (tasks) {
        return Scaffold(
          appBar: const CustomAppBar(title: "Edit Task"),
          backgroundColor: defaultBackgroundColor,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: _title,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      labelStyle: TextStyle(color: subtitleTextColor),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: textColor),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a task title';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _title = value!;
                    },
                  ),
                  const SizedBox(height: 20.0),
                  GestureDetector(
                    onTap: _pickDueDateTime,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: _dueDate == null
                              ? 'Select Due Date & Time'
                              : 'Due Date & Time',
                          labelStyle: TextStyle(color: subtitleTextColor),
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                        controller: TextEditingController(
                          text: _dueDate != null
                              ? DateFormat('dd/MM/yyyy HH:mm').format(_dueDate!)
                              : '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  DropdownButtonFormField<int>(
                    value: _priority,
                    decoration: InputDecoration(
                      labelText: 'Priority',
                      labelStyle: TextStyle(color: subtitleTextColor),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: subtitleTextColor),
                    items: const [
                      DropdownMenuItem(
                          value: 1,
                          child: Text('Low',
                              style: TextStyle(
                                color: Colors.grey,
                              ))),
                      DropdownMenuItem(
                          value: 2,
                          child: Text('Medium',
                              style: TextStyle(
                                color: Colors.grey,
                              ))),
                      DropdownMenuItem(
                          value: 3,
                          child: Text('High',
                              style: TextStyle(
                                color: Colors.grey,
                              ))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _priority = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20.0),
                  TextFormField(
                    initialValue: _notes,
                    decoration: InputDecoration(
                      labelText: 'Additional Notes',
                      labelStyle: TextStyle(color: subtitleTextColor),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(color: textColor),
                    maxLines: 3, // Allow multiple lines for notes
                    onSaved: (value) {
                      _notes = value;
                    },
                  ),
                  const SizedBox(height: 20.0),
                  if (_attachments.isNotEmpty)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Attachments',
                                style: TextStyle(color: textColor)),
                            IconButton(
                              icon: Icon(
                                _attachmentsExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: textColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _attachmentsExpanded = !_attachmentsExpanded;
                                });
                              },
                            ),
                          ],
                        ),
                        _buildAttachmentPreviews(),
                      ],
                    ),
                  const SizedBox(height: 20.0), // Adjusted spacing
                  Center(
                    child: ElevatedButton(
                      onPressed: _submitTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30.0, vertical: 15.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: const Text(
                        'Update Task',
                        style: TextStyle(fontSize: 16.0, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAttachmentOptions,
            backgroundColor: accentColor,
            child: const Icon(Icons.attach_file, color: Colors.black),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.red, fontSize: 18),
        ),
      ),
    );
  }
}
