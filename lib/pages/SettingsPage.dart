import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:respire/services/TranslationProvider/TranslationProvider.dart';
import 'package:respire/theme/Colors.dart';
import 'package:respire/services/TranslationProvider/AppLanguage.dart';
import 'package:respire/services/SettingsProvider.dart';
import 'package:respire/utils/TextUtils.dart';
import 'package:respire/components/BreathingPage/BreathMonitorIndicator.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  TranslationProvider translationProvider = TranslationProvider();

  bool photoAdded = false;
  bool _isTestingBreath = false;
  final ValueNotifier<bool> _isPausedNotifier = ValueNotifier<bool>(true);

  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Widget _monitoringBox(double screenWidth) {
    return Container(
      width: screenWidth * 0.9,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            translationProvider.getTranslation(
              "SettingsPage.monitoring_section_title",
            ) !=
                ""
                ? translationProvider.getTranslation(
              "SettingsPage.monitoring_section_title",
            )
                : "Breath Monitoring",
            style: const TextStyle(
              fontSize: 26,
              fontFamily: 'Glacial',
              fontWeight: FontWeight.w300,
              color: Colors.black,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      translationProvider.getTranslation(
                        "SettingsPage.threshold_label",
                      ) !=
                          ""
                          ? translationProvider.getTranslation(
                        "SettingsPage.threshold_label",
                      )
                          : "Exhale Threshold",
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      SettingsProvider()
                          .settings
                          .breathThreshold
                          .toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkerblue,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: SettingsProvider().settings.breathThreshold,
                  min: 0.1,
                  max: 0.9,
                  divisions: 16,
                  activeColor: darkerblue,
                  onChanged: (value) {
                    setState(() {
                      SettingsProvider().settings.breathThreshold = value;
                      SettingsProvider().saveSettings();
                    });
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isTestingBreath = !_isTestingBreath;
                      _isPausedNotifier.value = !_isTestingBreath;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTestingBreath
                        ? Colors.red.shade400
                        : mediumblue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: _isTestingBreath ? EdgeInsets.zero : null,
                    fixedSize: _isTestingBreath
                        ? const Size(48, 48)
                        : null,
                  ),
                  child: _isTestingBreath
                      ? const Icon(Icons.stop)
                      : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow),
                      const SizedBox(width: 8),
                      Text(
                        translationProvider.getTranslation(
                          "SettingsPage.test_button_label",
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isTestingBreath) ...[
                  const SizedBox(height: 20),
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        BreathMonitorIndicator(
                          isPaused: _isPausedNotifier,
                          threshold: SettingsProvider()
                              .settings
                              .breathThreshold,
                        ),
                        Positioned(
                          top: 8,
                          child: Text(
                            translationProvider.getTranslation(
                              "SettingsPage.test_hint",
                            ) !=
                                ""
                                ? translationProvider.getTranslation(
                              "SettingsPage.test_hint",
                            )
                                : "Breathe/Blow into mic to test",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _firstBox(double screenWidth) {
    return Container(
      width: screenWidth * 0.9,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            translationProvider.getTranslation(
              "SettingsPage.app_section_title",
            ),
            style: const TextStyle(
              fontSize: 26,
              fontFamily: 'Glacial',
              fontWeight: FontWeight.w300,
              color: Colors.black,
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: mediumblue,
                width: 1,
              ),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    translationProvider.getTranslation(
                      "SettingsPage.language_label",
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  DropdownButton2<AppLanguage>(
                    underline: const SizedBox(),
                    value: SettingsProvider().currentLanguage,
                    onChanged: (value) async {
                      SettingsProvider().setLanguage(value!);
                      await translationProvider.loadLanguage(value);

                      if (mounted) {
                        setState(() {});
                      }
                    },
                    items: AppLanguage.supportedLanguages
                        .map(
                          (lang) => DropdownMenuItem<AppLanguage>(
                        value: lang,
                        child: Text(lang.name),
                      ),
                    )
                        .toList(),
                    iconStyleData: IconStyleData(
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: darkerblue,
                      ),
                    ),
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secondBox(double screenWidth) {
    return Container(
      width: screenWidth * 0.9,
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            translationProvider.getTranslation(
              "SettingsPage.app_second_section_title",
            ),
            style: const TextStyle(
              fontSize: 26,
              fontFamily: 'Glacial',
              fontWeight: FontWeight.w300,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
            ),
            child: Text(
              TextUtils.addNoBreakingSpaces(
                translationProvider.getTranslation(
                  "SettingsPage.app_description",
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          const Image(
            image: AssetImage(
              'assets/group_logo.png',
            ),
            fit: BoxFit.contain,
            height: 75,
          ),
          const SizedBox(height: 20),

          // App version
          if (_appVersion.isNotEmpty)
            Text(
              "${translationProvider.getTranslation(
                "SettingsPage.version",
              )} $_appVersion",
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 4),

          Text(
            "© ${DateTime.now().year} "
                "${translationProvider.getTranslation(
              "SettingsPage.copyright",
            )}",
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth =
        MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          translationProvider.getTranslation(
            "SettingsPage.page_title",
          ),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Glacial',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      backgroundColor: mediumblue,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 20.0,
            bottom: 20.0,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _firstBox(screenWidth),
                const SizedBox(height: 20),
                _monitoringBox(screenWidth),
                const SizedBox(height: 20),
                _secondBox(screenWidth),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
