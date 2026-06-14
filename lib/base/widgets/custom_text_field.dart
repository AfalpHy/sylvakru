import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/widgets/my_navigator.dart';

class CustomTextField extends StatefulWidget {
  final String? name;
  final TextEditingController controller;
  final bool expand;
  final bool onlyNumber;
  final bool compact;
  final bool autoFocus;

  const CustomTextField(
    this.name,
    this.controller, {
    super.key,
    this.expand = false,
    this.onlyNumber = false,
    this.compact = true,
    this.autoFocus = false,
  });

  @override
  State<StatefulWidget> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  FocusNode textFieldNode = FocusNode();

  @override
  void initState() {
    super.initState();
    textFieldNode.addListener(() {
      isTyping = textFieldNode.hasFocus;
      if (Platform.isAndroid) {
        canFocusNavigatorNotifier.value = !isTyping;
      }
    });
  }

  @override
  void dispose() {
    textFieldNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specificTextcolor = colorManager.getSpecificTextColor();

    return Column(
      children: [
        if (widget.name != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${widget.name}:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

        Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: specificTextcolor.withAlpha(50),
              cursorColor: specificTextcolor,
              selectionHandleColor: specificTextcolor,
            ),
          ),
          child: TextField(
            focusNode: textFieldNode,
            autofocus: widget.autoFocus,
            keyboardType: widget.onlyNumber ? .number : null,
            minLines: widget.expand ? 3 : 1,
            maxLines: widget.expand ? null : 1,
            style: TextStyle(fontSize: 12),
            controller: widget.controller,
            decoration: InputDecoration(
              visualDensity: widget.compact ? .new(vertical: -2.5) : null,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: specificTextcolor),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: specificTextcolor, width: 1.5),
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
