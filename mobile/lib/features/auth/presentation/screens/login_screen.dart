import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/formatters/ru_phone_formatter.dart";
import "../../../../core/network/error_message.dart";
import "../controllers/auth_controller.dart";
import "../widgets/turnstile_view.dart";
import "../../data/repositories/auth_repository_impl.dart";
import "../../domain/models/auth_protection.dart";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _extraPhoneController = TextEditingController();
  final _extraEmailController = TextEditingController();

  AuthProtectionConfig _protection = AuthProtectionConfig.disabled();
  String _turnstileToken = "";
  int _turnstileReset = 0;
  PhoneChallenge? _phoneChallenge;
  final _phoneCodeController = TextEditingController();
  Timer? _receivePollTimer;

  void _resetTurnstile() {
    _turnstileToken = "";
    _turnstileReset += 1;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final protection = await ref
            .read(authRepositoryProvider)
            .fetchProtection();
        if (!mounted) {
          return;
        }
        setState(() {
          _protection = protection;
        });
      } catch (_) {
        // Protection is optional for local/dev without GreenSMS/Turnstile.
      }
    });
  }

  @override
  void dispose() {
    _receivePollTimer?.cancel();
    _identifierController.dispose();
    _extraPhoneController.dispose();
    _extraEmailController.dispose();
    _phoneCodeController.dispose();
    super.dispose();
  }

  void _setChallenge(PhoneChallenge? challenge) {
    _phoneChallenge = challenge;
    _syncReceivePoll();
  }

  void _syncReceivePoll() {
    _receivePollTimer?.cancel();
    final challenge = _phoneChallenge;
    if (challenge == null || !challenge.isReceive || challenge.verified) {
      return;
    }
    _receivePollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollReceiveChallenge());
    });
  }

  Future<void> _pollReceiveChallenge() async {
    final challenge = _phoneChallenge;
    if (challenge == null || !challenge.isReceive || !mounted) {
      return;
    }

    try {
      final next = await ref
          .read(authRepositoryProvider)
          .verifyPhoneChallenge(challengeId: challenge.challengeId);
      if (!mounted) {
        return;
      }
      if (next.verified) {
        setState(() => _setChallenge(next));
        await ref
            .read(authControllerProvider.notifier)
            .login(
              identifier: normalizeLoginIdentifier(_identifierController.text),
              phoneChallengeId: next.challengeId,
            );
      }
    } catch (_) {
      // Звонок ещё не поступил.
    }
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    if (_phoneChallenge != null &&
        _phoneChallenge!.needsCode &&
        _phoneCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _phoneChallenge!.isCall
                ? "Введите последние 4 цифры входящего номера"
                : "Введите код подтверждения телефона",
          ),
        ),
      );
      return;
    }

    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            identifier: normalizeLoginIdentifier(_identifierController.text),
            turnstileToken: _turnstileToken,
            phoneChallengeId: _phoneChallenge?.challengeId ?? "",
            phoneCode: _phoneCodeController.text.trim(),
          );
    } on PhoneConfirmationRequired catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _setChallenge(error.challenge);
        _phoneCodeController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.challenge.detail)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(_resetTurnstile);
    }
  }

  void _applyDemoCredentials() {
    _identifierController.text = "anna@econizhny.local";
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        setState(_resetTurnstile);
      }

      if (next.status == AuthStatus.authenticated ||
          next.status == AuthStatus.guest) {
        context.go("/app");
      }
    });

    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.surface, theme.scaffoldBackgroundColor],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AuthHeader(),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Вход",
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Укажите почту, телефон или логин — отправим код. Если аккаунта ещё нет, он появится после подтверждения.",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _LoginForm(
                              key: const ValueKey("login-form"),
                              formKey: _loginFormKey,
                              identifierController: _identifierController,
                              onClearError: () {
                                ref
                                    .read(authControllerProvider.notifier)
                                    .clearError();
                              },
                              onSubmit: _submitLogin,
                            ),
                            if (authState.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              _AuthErrorBanner(
                                message: authState.errorMessage!,
                              ),
                            ],
                            if (_phoneChallenge != null) ...[
                              const SizedBox(height: 16),
                              _PhoneChallengeBlock(
                                challenge: _phoneChallenge!,
                                codeController: _phoneCodeController,
                                extraPhoneController: _extraPhoneController,
                                extraEmailController: _extraEmailController,
                                isBusy: authState.isBusy,
                                onSwitchChannel: (channel) async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final extraPhone = _extraPhoneController.text
                                      .trim();
                                  final extraEmail = _extraEmailController.text
                                      .trim();
                                  const phoneChannels = {
                                    "telegram",
                                    "call",
                                    "receive",
                                  };
                                  if (phoneChannels.contains(channel) &&
                                      _phoneChallenge!.phone.isEmpty &&
                                      extraPhone.isEmpty) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Укажите номер телефона для этого способа",
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (channel == "email" &&
                                      _phoneChallenge!.email.isEmpty &&
                                      extraEmail.isEmpty) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Укажите почту для этого способа",
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  try {
                                    final next = await ref
                                        .read(authRepositoryProvider)
                                        .sendAuthChallenge(
                                          challengeId:
                                              _phoneChallenge!.challengeId,
                                          channel: channel,
                                          phone: extraPhone,
                                          email: extraEmail,
                                          turnstileToken: _turnstileToken,
                                        );
                                    if (!mounted) {
                                      return;
                                    }
                                    setState(() {
                                      _setChallenge(next);
                                      _phoneCodeController.clear();
                                    });
                                  } catch (error) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          humanizeNetworkError(
                                            error,
                                            fallback:
                                                "Не удалось отправить код другим способом",
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                            if (_protection.hasTurnstile &&
                                _phoneChallenge == null) ...[
                              const SizedBox(height: 16),
                              TurnstileView(
                                key: ValueKey("turnstile-$_turnstileReset"),
                                siteKey: _protection.turnstileSiteKey,
                                onToken: (token) {
                                  setState(() {
                                    _turnstileToken = token;
                                  });
                                },
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: authState.isBusy ? null : _submitLogin,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              icon: authState.isBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                _phoneChallenge == null
                                    ? "Получить код"
                                    : "Подтвердить и войти",
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: authState.isBusy
                                  ? null
                                  : _applyDemoCredentials,
                              icon: const Icon(Icons.flash_on_outlined),
                              label: const Text("Подставить демо-аккаунт"),
                            ),
                            const SizedBox(height: 4),
                            OutlinedButton.icon(
                              onPressed: authState.isBusy
                                  ? null
                                  : () {
                                      ref
                                          .read(authControllerProvider.notifier)
                                          .continueAsGuest();
                                    },
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text("Продолжить как гость"),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Вход и создание аккаунта означают принятие пользовательского соглашения, политики конфиденциальности и согласие на обработку персональных данных.",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            TextButton(
                              onPressed: () => context.push("/profile/help"),
                              child: const Text("Открыть документы"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset("assets/app_icon.png", fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "ЭкоВыхухоль",
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Лента, карта и профиль в одном приложении.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneChallengeBlock extends StatelessWidget {
  const _PhoneChallengeBlock({
    required this.challenge,
    required this.codeController,
    required this.extraPhoneController,
    required this.extraEmailController,
    required this.isBusy,
    required this.onSwitchChannel,
  });

  final PhoneChallenge challenge;
  final TextEditingController codeController;
  final TextEditingController extraPhoneController;
  final TextEditingController extraEmailController;
  final bool isBusy;
  final Future<void> Function(String channel) onSwitchChannel;

  static const _labels = {
    "telegram": "Код в Telegram",
    "call": "Код в номере",
    "receive": "Обратный звонок",
    "email": "Код на почту",
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherChannels = challenge.availableChannels
        .where((channel) => channel != challenge.channel)
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(challenge.detail, style: theme.textTheme.bodyMedium),
          if (challenge.isReceive) ...[
            const SizedBox(height: 12),
            Text(
              challenge.receiveNumber,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: challenge.codeLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: "",
                labelText: challenge.isCall
                    ? "Последние 4 цифры входящего номера"
                    : challenge.isEmail
                    ? "Код из письма"
                    : "Код из Telegram",
              ),
            ),
          ],
          if (challenge.phone.isEmpty) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: extraPhoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: const [RuPhoneInputFormatter(optional: true)],
              decoration: const InputDecoration(
                labelText: "Номер телефона",
                hintText: "+7 (999) 000-00-00",
              ),
            ),
          ],
          if (challenge.email.isEmpty) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: extraEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Электронная почта"),
            ),
          ],
          for (final channel in otherChannels)
            TextButton(
              onPressed: isBusy ? null : () => onSwitchChannel(channel),
              child: Text(_labels[channel] ?? channel),
            ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required super.key,
    required this.formKey,
    required this.identifierController,
    required this.onClearError,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController identifierController;
  final VoidCallback onClearError;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: identifierController,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
                AutofillHints.telephoneNumber,
              ],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              inputFormatters: const [RuPhoneInputFormatter(optional: true)],
              onChanged: (_) => onClearError(),
              onFieldSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                labelText: "Почта, телефон или логин",
                hintText: "Например, anna@econizhny.local",
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Введите почту, телефон или логин";
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
