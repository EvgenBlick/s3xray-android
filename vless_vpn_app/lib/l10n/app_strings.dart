import 'package:flutter/widgets.dart';

import '../features/import/domain/import_link_error.dart';
import '../features/vpn/application/server_latency_probe.dart';
import '../features/vpn/application/vpn_controller.dart';

class AppStrings {
  const AppStrings._(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static AppStrings of(BuildContext context) {
    final AppStrings? strings = Localizations.of<AppStrings>(
      context,
      AppStrings,
    );
    assert(strings != null, 'AppStrings not found in context');
    return strings!;
  }

  bool get isRussian => locale.languageCode == 'ru';

  String get appName => isRussian ? 'Samurai Service' : 'Samurai Service';
  String get livePreviewLabel => isRussian
      ? 'Выбор сервера и подключение'
      : 'Server selection and connect';
  String get addLinkAction => isRussian ? 'Добавить ссылку' : 'Add link';
  String get settingsTitle => isRussian ? 'Настройки' : 'Settings';
  String get navVpnLabel => isRussian ? 'VPN' : 'VPN';
  String get navSubscriptionLabel => isRussian ? 'Подписка' : 'Subscription';
  String get navSupportLabel => isRussian ? 'Поддержка' : 'Support';
  String get navProfileLabel => isRussian ? 'Профиль' : 'Profile';
  String get cabinetTitle =>
      isRussian ? 'Аккаунт и подписка' : 'Account and subscription';
  String get cabinetSubtitle => isRussian
      ? 'Данные кабинета, подписка и выход из аккаунта'
      : 'Cabinet data, subscription and sign out';
  String get cabinetUserLabel => isRussian ? 'Пользователь' : 'User';
  String get cabinetBalanceLabel => isRussian ? 'Баланс' : 'Balance';
  String get cabinetDevicesLabel => isRussian ? 'Устройства' : 'Devices';
  String get cabinetRefreshAction =>
      isRussian ? 'Обновить данные' : 'Refresh data';
  String get cabinetRefreshCompactAction => isRussian ? 'Обновить' : 'Refresh';
  String get cabinetLogoutAction => isRussian ? 'Выйти' : 'Sign out';
  String get purchaseOpenAction =>
      isRussian ? 'Купить подписку' : 'Buy subscription';
  String get purchaseRenewAction =>
      isRussian ? 'Продлить подписку' : 'Renew subscription';
  String get purchaseTitle =>
      isRussian ? 'Покупка подписки' : 'Subscription purchase';
  String get purchaseBody => isRussian
      ? 'Этот экран использует те же backend-методы, что и кабинет. Можно купить новую подписку или продлить текущую, не выходя из приложения.'
      : 'This screen uses the same backend methods as the cabinet. You can buy a new subscription or renew the current one without leaving the app.';
  String get subscriptionTabBody => isRussian
      ? 'Подключайте больше устройств и пользуйтесь сервисом вместе с друзьями и близкими.'
      : 'Connect more devices and use the service together with friends and family.';
  String get purchaseLoadingMessage => isRussian
      ? 'Загружаем варианты покупки...'
      : 'Loading purchase options...';
  String get purchaseUnavailableMessage => isRussian
      ? 'Варианты покупки сейчас недоступны.'
      : 'Purchase options are unavailable right now.';
  String get purchaseTariffsTitle =>
      isRussian ? 'Доступные тарифы' : 'Available tariffs';
  String get purchasePeriodsTitle =>
      isRussian ? 'Периоды покупки' : 'Purchase periods';
  String get purchaseConfirmAction =>
      isRussian ? 'Оплатить подписку' : 'Pay subscription';
  String get purchasePayAction => isRussian ? 'Оплатить' : 'Pay';
  String get purchaseActivateAction =>
      isRussian ? 'Купить и активировать' : 'Buy and activate';
  String get purchaseProcessingAction =>
      isRussian ? 'Проводим оплату...' : 'Processing payment...';
  String get purchaseTotalLabel => isRussian ? 'Итого' : 'Total';
  String get purchasePerMonthLabel => isRussian ? 'В месяц' : 'Per month';
  String get purchaseDevicesSubtitle =>
      isRussian ? 'Одновременно' : 'Simultaneous';
  String get purchaseFlowHint => isRussian
      ? '1. Устройства  •  2. Срок подписки'
      : '1. Devices  •  2. Subscription term';
  String get purchasePopularBadge => isRussian ? '🔥 Популярный' : '🔥 Popular';
  String get notificationPurchaseTitle =>
      isRussian ? 'Подписка активирована' : 'Subscription activated';
  String get notificationPurchaseBody => isRussian
      ? 'Покупка успешно применена. Можно подключать VPN.'
      : 'Your purchase was applied. You can connect the VPN.';
  String notificationUpdateTitle(String versionName) => isRussian
      ? 'Доступно обновление $versionName'
      : 'Update $versionName is available';
  String get notificationUpdateBody => isRussian
      ? 'Откройте приложение, чтобы скачать новую версию Samurai Service.'
      : 'Open the app to download the latest Samurai Service version.';
  String get notificationSupportReplyTitle =>
      isRussian ? 'Ответ от поддержки' : 'Support replied';
  String get notificationSupportReplyBody => isRussian
      ? 'Откройте приложение, чтобы прочитать ответ в тикете.'
      : 'Open the app to read the reply in your ticket.';
  String get currentValue => isRussian ? 'Текущий' : 'Current';
  String get cabinetLoadingMessage => isRussian
      ? 'Данные аккаунта загружаются...'
      : 'Account data is loading...';
  String get cabinetNoSubscriptionLabel =>
      isRussian ? 'Нет активной подписки' : 'No active subscription';
  String get settingsBody => isRussian
      ? 'Системные и VPN-настройки, которые не должны засорять основной экран.'
      : 'System and VPN settings that should stay out of the main screen.';
  String get settingsLoginSubtitle => isRussian
      ? 'Войти в кабинет и подтянуть подписку автоматически'
      : 'Sign in to the cabinet and load the subscription automatically';
  String get profileGuestTitle => isRussian
      ? 'Профиль недоступен без входа'
      : 'Profile is unavailable without sign in';
  String get profileGuestBody => isRussian
      ? 'Войдите в кабинет, чтобы увидеть аккаунт, баланс, подписку и управление выходом.'
      : 'Sign in to see your account, balance, subscription and sign-out controls.';
  String get subscriptionGuestTitle => isRussian
      ? 'Покупка доступна после входа'
      : 'Purchase is available after sign in';
  String get subscriptionGuestBody => isRussian
      ? 'Войдите в кабинет, чтобы купить или продлить подписку через тот же backend, что и в web-кабинете.'
      : 'Sign in to buy or renew a subscription using the same backend as the web cabinet.';
  String get supportTitle => isRussian ? 'Поддержка' : 'Support';
  String get supportBody => isRussian
      ? 'Создайте тикет, следите за ответами поддержки и продолжайте диалог прямо в приложении.'
      : 'Create a ticket, follow support replies and continue the conversation directly in the app.';
  String get supportCreateAction => isRussian ? 'Новый тикет' : 'New ticket';
  String get supportEmptyTitle =>
      isRussian ? 'Пока нет обращений' : 'No support requests yet';
  String get supportEmptyBody => isRussian
      ? 'Опишите проблему — поддержка увидит тикет и ответит здесь.'
      : 'Describe the issue and support will reply here.';
  String get supportOpenTicketTitle =>
      isRussian ? 'Открытые обращения' : 'Open tickets';
  String get supportClosedTicketLabel => isRussian ? 'Закрыт' : 'Closed';
  String get supportBlockedReplyLabel =>
      isRussian ? 'Ответы заблокированы' : 'Replies are blocked';
  String get supportComposerHint =>
      isRussian ? 'Напишите сообщение поддержке' : 'Write a message to support';
  String get supportSendAction => isRussian ? 'Отправить' : 'Send';
  String get supportCloseAction => isRussian ? 'Закрыть тикет' : 'Close ticket';
  String get supportHideThreadAction =>
      isRussian ? 'Скрыть диалог' : 'Hide conversation';
  String get supportLoginTitle => isRussian
      ? 'Войдите, чтобы открыть поддержку'
      : 'Sign in to open support';
  String get supportLoginBody => isRussian
      ? 'Тикеты поддержки привязаны к кабинету. После входа вы увидите историю переписки и ответы операторов.'
      : 'Support tickets are linked to your cabinet. Sign in to see your history and operator replies.';
  String get supportLoadingLabel =>
      isRussian ? 'Загружаем поддержку…' : 'Loading support…';
  String get supportCreateSheetTitle =>
      isRussian ? 'Новое обращение' : 'New ticket';
  String get supportTicketTitleLabel =>
      isRussian ? 'Тема обращения' : 'Ticket title';
  String get supportTicketTitleHint => isRussian
      ? 'Например: Не проходит оплата'
      : 'For example: Payment does not go through';
  String get supportTicketMessageLabel => isRussian ? 'Сообщение' : 'Message';
  String get supportTicketMessageHint => isRussian
      ? 'Опишите проблему как можно подробнее'
      : 'Describe the issue in as much detail as possible';
  String get supportSubmitTicketAction =>
      isRussian ? 'Создать тикет' : 'Create ticket';
  String get supportCreateSubmitAction =>
      isRussian ? 'Создать тикет' : 'Create ticket';
  String get supportBackToTicketsAction =>
      isRussian ? 'К списку тикетов' : 'Back to tickets';
  String get supportOnlineLabel => isRussian ? 'Онлайн' : 'Online';
  String get supportConnectingLabel =>
      isRussian ? 'Подключаем realtime…' : 'Connecting realtime…';
  String get supportContactFallbackTitle => isRussian
      ? 'Поддержка доступна через профиль'
      : 'Support is available through your profile';
  String supportContactFallbackBody(String? username) => isRussian
      ? 'Сейчас тикеты отключены на backend. Для быстрого контакта используйте профиль кабинета${username == null || username.isEmpty ? '' : ' или Telegram $username'}.'
      : 'Tickets are currently disabled on the backend. Use your cabinet profile${username == null || username.isEmpty ? '' : ' or Telegram $username'} for support.';
  String get supportNoMessagesLabel =>
      isRussian ? 'Сообщений пока нет' : 'No messages yet';
  String get supportLoadingMessage =>
      isRussian ? 'Загружаем обращения...' : 'Loading support tickets...';
  String get supportNeedLoginTitle => isRussian
      ? 'Поддержка доступна после входа'
      : 'Support is available after sign in';
  String get supportNeedLoginBody => isRussian
      ? 'Войдите в кабинет, чтобы видеть свои тикеты и получать ответы поддержки.'
      : 'Sign in to the cabinet to see your tickets and receive support replies.';
  String get supportThreadTitle =>
      isRussian ? 'Диалог по тикету' : 'Ticket conversation';
  String get supportReplyFromSupport => isRussian ? 'Поддержка' : 'Support';
  String get supportReplyFromYou => isRussian ? 'Вы' : 'You';
  String get supportValidationTitle => isRussian
      ? 'Введите тему не короче 3 символов.'
      : 'Enter a title with at least 3 characters.';
  String get supportValidationMessage => isRussian
      ? 'Сообщение должно быть не короче 10 символов.'
      : 'Message must be at least 10 characters long.';
  String supportStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'answered':
        return isRussian ? 'Есть ответ' : 'Answered';
      case 'pending':
        return isRussian ? 'Ждёт ответа' : 'Pending';
      case 'closed':
        return isRussian ? 'Закрыт' : 'Closed';
      case 'open':
      default:
        return isRussian ? 'Открыт' : 'Open';
    }
  }

  String get vpnSettingsTitle =>
      isRussian ? 'VPN и устройство' : 'VPN and device';
  String get vpnSettingsBody => isRussian
      ? 'Исключения приложений и системные VPN-настройки вынесены сюда, чтобы не засорять главный экран.'
      : 'App exclusions and VPN system settings live here so the main screen stays clean.';
  String get addFirstSubscriptionAction =>
      isRussian ? 'Добавить подписку' : 'Add subscription';
  String get authGateTitle =>
      isRussian ? 'Быстрый вход в кабинет' : 'Fast cabinet sign in';
  String get authGateBody => isRussian
      ? 'Авторизуйтесь через доступный провайдер и приложение сразу подтянет подписку, профиль и доступные серверы.'
      : 'Sign in with an available provider and the app will immediately load your subscription, profile, and available servers.';
  String get authLoginTitle => isRussian ? 'Вход в аккаунт' : 'Sign in';
  String get authLoginBody => isRussian
      ? 'Выберите удобный способ входа. После авторизации приложение автоматически подтянет подписку и настройки кабинета.'
      : 'Choose the sign-in method you prefer. After authorization, the app will automatically load your subscription and cabinet settings.';
  String get authOtherMethodsTitle =>
      isRussian ? 'Доступные способы входа' : 'Available sign-in methods';
  String get authLoginAction => isRussian ? 'Войти' : 'Sign in';
  String get authLoggingInAction => isRussian ? 'Входим...' : 'Signing in...';
  String get authProfileLoadingMessage => isRussian
      ? 'Подтягиваем профиль и подписку...'
      : 'Loading profile and subscription...';
  String get authContinueAsGuestAction =>
      isRussian ? 'Добавить подписку вручную' : 'Add subscription manually';
  String get authEmailLabel => isRussian ? 'Email' : 'Email';
  String get authPasswordLabel => isRussian ? 'Пароль' : 'Password';
  String get authMissingCredentialsError =>
      isRussian ? 'Введите email и пароль.' : 'Enter the email and password.';
  String get authGenericError =>
      isRussian ? 'Не удалось выполнить вход.' : 'Failed to sign in.';
  String get authNoMethodsAvailable => isRussian
      ? 'Сейчас backend не отдает доступных способов входа.'
      : 'The backend is not exposing any sign-in methods right now.';
  String get authOAuthTimeoutError => isRussian
      ? 'Браузер не вернул приложение в течение ожидаемого времени.'
      : 'The browser did not return to the app in time.';
  String get authOAuthOpenBrowserError => isRussian
      ? 'Не удалось открыть браузер для входа.'
      : 'Failed to open the browser for sign in.';
  String get authProviderNotReadyError => isRussian
      ? 'Этот способ входа уже найден на backend, но mobile callback для него еще не подключен.'
      : 'This sign-in method is available on the backend, but the mobile callback is not wired yet.';
  String get refreshSubscriptionAction =>
      isRussian ? 'Обновить подписку' : 'Refresh subscription';
  String get updateNowAction =>
      isRussian ? 'Обновить приложение' : 'Update app';
  String get updateContinueAction =>
      isRussian ? 'Продолжить установку' : 'Continue install';
  String updateAvailableTitle(String versionName) => isRussian
      ? 'Доступна версия $versionName'
      : 'Version $versionName is available';
  String get updateAvailableBody => isRussian
      ? 'Новая сборка уже опубликована. Загрузите APK и запустите обновление прямо из приложения.'
      : 'A new build is available. Download the APK and start the update directly from the app.';
  String get updateDownloadingTitle =>
      isRussian ? 'Загружается обновление' : 'Downloading update';
  String updateDownloadingBody(double? progress) {
    if (progress == null) {
      return isRussian
          ? 'APK загружается на устройство.'
          : 'The APK is being downloaded to the device.';
    }

    final int percent = (progress * 100).clamp(0, 100).round();
    return isRussian
        ? 'Загружено $percent%. После завершения откроется установка.'
        : '$percent% downloaded. Installation will open when the download finishes.';
  }

  String get updateInstallingTitle =>
      isRussian ? 'Установка подготовлена' : 'Install prepared';
  String get updateInstallingBody => isRussian
      ? 'Android должен открыть системный экран установки APK.'
      : 'Android should open the system APK installation screen.';
  String get updatePermissionTitle => isRussian
      ? 'Нужно разрешение на установку'
      : 'Install permission required';
  String get updatePermissionBody => isRussian
      ? 'Android откроет системный экран, где нужно разрешить установку APK из этого приложения.'
      : 'Android will open a system screen where you need to allow APK installs from this app.';
  String get updateErrorTitle =>
      isRussian ? 'Не удалось обновить приложение' : 'Failed to update app';
  String get updateErrorBody => isRussian
      ? 'Проверьте сеть или manifest и повторите попытку.'
      : 'Check the network or manifest and try again.';
  String get retryAction => isRussian ? 'Повторить' : 'Retry';
  String splitTunnelAction(int count) => isRussian
      ? (count == 0 ? 'Исключить приложения' : 'Исключения: $count')
      : (count == 0 ? 'Exclude apps' : 'Excluded: $count');
  String get splitTunnelTitle =>
      isRussian ? 'Исключения из VPN' : 'VPN exclusions';
  String get splitTunnelBody => isRussian
      ? 'Выбранные приложения будут обходить VPN и использовать обычную сеть устройства.'
      : 'Selected apps will bypass the VPN and use the device network directly.';
  String get splitTunnelSearchHint =>
      isRussian ? 'Поиск приложения или пакета' : 'Search app or package';
  String splitTunnelSelectedCount(int count) =>
      isRussian ? 'Выбрано приложений: $count' : 'Selected apps: $count';
  String get splitTunnelEmptySearch =>
      isRussian ? 'Ничего не найдено.' : 'Nothing found.';
  String get splitTunnelUnavailable => isRussian
      ? 'Android пока не дал приложению доступный список установленных приложений. Поставьте свежую сборку и откройте экран снова.'
      : 'Android has not exposed the installed apps list to the application yet. Install the latest build and open this screen again.';
  String get clearSplitTunnelAction => isRussian ? 'Сбросить' : 'Clear';
  String get saveSplitTunnelAction => isRussian ? 'Сохранить' : 'Save';
  String get importFromClipboardAction =>
      isRussian ? 'Импортировать из буфера' : 'Import from clipboard';
  String get useClipboardAction => isRussian ? 'Вставить' : 'Paste';
  String get clipboardReadyLabel => isRussian
      ? 'Ссылка уже найдена в буфере обмена'
      : 'A link was found in the clipboard';
  String get updatePingAction => isRussian ? 'Обновить пинг' : 'Refresh ping';
  String get connectionTimeLabel =>
      isRussian ? 'Время подключения' : 'Connection time';
  String get serversTitle => isRussian ? 'Серверы' : 'Servers';
  String get groupsTitle => isRussian ? 'Группы' : 'Groups';
  String get subscriptionTitle => isRussian ? 'Подписка' : 'Subscription';
  String get trafficUsedLabel => isRussian ? 'Израсходовано' : 'Used';
  String get trafficLeftLabel => isRussian ? 'Осталось' : 'Remaining';
  String get trafficTotalLabel => isRussian ? 'Лимит' : 'Total';
  String get expiresInLabel => isRussian ? 'Действует' : 'Valid for';
  String get updateEveryLabel => isRussian ? 'Обновление' : 'Updates';
  String get supportLabel => isRussian ? 'Поддержка' : 'Support';
  String get announcementLabel => isRussian ? 'Сообщение' : 'Announcement';
  String get noSubscriptionInfo => isRussian
      ? 'Метаданные подписки пока не получены.'
      : 'Subscription metadata has not been loaded yet.';
  String get subscriptionActiveLabel =>
      isRussian ? 'Подписка активна' : 'Subscription active';
  String get subscriptionRemoteLabel =>
      isRussian ? 'Удаленная подписка' : 'Remote subscription';
  String get unlimitedValue => isRussian ? 'Без лимита' : 'Unlimited';
  String get refreshedNowValue => isRussian ? 'Только что' : 'Just now';
  String get subscriptionUpdatedMessage =>
      isRussian ? 'Подписка обновлена.' : 'Subscription updated.';
  String get subscriptionUpdateFailedMessage => isRussian
      ? 'Не удалось обновить подписку.'
      : 'Failed to refresh subscription.';
  String get pingRefreshTooltip =>
      isRussian ? 'Проверить пинг заново' : 'Recheck ping';
  String serversCount(int count, {int? total}) {
    if (total != null && total != count) {
      return isRussian
          ? 'В группе: $count из $total'
          : 'In group: $count of $total';
    }

    return isRussian
        ? 'Точек в подписке: $count'
        : 'Servers in subscription: $count';
  }

  String groupsCount(int count) {
    return isRussian
        ? 'Групп в подписке: $count'
        : 'Groups in subscription: $count';
  }

  String get selectedServerTitle =>
      isRussian ? 'Инфо по точке' : 'Selected server';
  String get sourceLinkTitle => isRussian ? 'Текущая ссылка' : 'Current link';
  String get sourceDirect =>
      isRussian ? 'Прямая VLESS-ссылка' : 'Direct VLESS link';
  String get sourceRemote =>
      isRussian ? 'Subscription-ссылка' : 'Subscription link';
  String get noServersTitle =>
      isRussian ? 'Нет доступных серверов' : 'No available servers';
  String get noServersBody => isRussian
      ? 'Добавьте ссылку сверху и выберите сервер после разбора.'
      : 'Add a link above and choose a server after parsing.';
  String get chooseServerHint => isRussian
      ? 'Выберите точку для подключения.'
      : 'Choose a server to connect.';
  String get pingLabel => isRussian ? 'Пинг' : 'Ping';
  String get statusLabel => isRussian ? 'Статус' : 'Status';
  String get serverMenuTitle => isRussian ? 'Меню действий' : 'Action menu';
  String get applyLinkAction => isRussian ? 'Применить ссылку' : 'Apply link';
  String get importHint => isRussian
      ? 'Вставьте VLESS или subscription-ссылку. Если ссылка уже скопирована, можно импортировать ее сразу из буфера.'
      : 'Paste a VLESS or subscription link. If the link is already copied, you can import it directly from the clipboard.';
  String get closeAction => isRussian ? 'Закрыть' : 'Close';
  String get androidFirstMvp =>
      isRussian ? 'Android-first MVP' : 'Android-first MVP';
  String get parsedState => isRussian ? 'Конфиг разобран' : 'VLESS parsed';
  String get waitingState => isRussian ? 'Жду ссылку' : 'Waiting for config';
  String get daysSuffix => isRussian ? 'дн' : 'days';
  String hoursValue(int hours) =>
      isRussian ? 'каждые $hours ч' : 'every $hours h';
  String get heroTitle => isRussian
      ? 'Одна ссылка.\nНесколько серверов.\nОдин туннель.'
      : 'One link.\nMultiple servers.\nOne tunnel.';
  String get heroBody => isRussian
      ? 'Верхняя кнопка добавляет ссылку, а центр экрана отдан выбору серверов, пингу и подключению.'
      : 'The top button adds a link, while the center of the screen is dedicated to server choice, ping, and connection.';
  String get transportLabel => isRussian ? 'Транспорт' : 'Transport';
  String get securityLabel => isRussian ? 'Защита' : 'Security';
  String get portLabel => isRussian ? 'Порт' : 'Port';
  String get flowLabel => isRussian ? 'Поток' : 'Flow';
  String get fpLabel => isRussian ? 'Отпечаток' : 'Fingerprint';
  String get pbkLabel => isRussian ? 'Публичный ключ' : 'Public key';
  String get importTitle => isRussian ? 'Импорт ссылки' : 'Import link';
  String get importBody => isRussian
      ? 'Вставка VLESS или subscription-ссылки, проверка и подготовка к подключению.'
      : 'Paste a VLESS or subscription link, validate it, and prepare for connection.';
  String get parseAction => isRussian ? 'Разобрать ссылку' : 'Parse config';
  String get resolvingAction =>
      isRussian ? 'Проверяю ссылку...' : 'Resolving link...';
  String get inputHint => isRussian
      ? 'vless://... или https://subscription/...'
      : 'vless://... or https://subscription/...';
  String get endpointTitle =>
      isRussian ? 'Выбранная точка' : 'Selected endpoint';
  String get endpointReady => isRussian ? 'Готово к bridge' : 'Ready to bridge';
  String get endpointReadyRemote =>
      isRussian ? 'Subscription разобран' : 'Subscription resolved';
  String get endpointMissing =>
      isRussian ? 'Нет валидного профиля' : 'No valid profile';
  String get endpointBody => isRussian
      ? 'После разбора здесь появятся параметры выбранного сервера и кнопки управления.'
      : 'After parsing, the selected server details and controls will appear here.';
  String get hostLabel => isRussian ? 'Хост' : 'Host';
  String get uuidLabel => 'UUID';
  String get sniLabel => 'SNI';
  String get remarkLabel => isRussian ? 'Метка' : 'Remark';
  String get missingValue => isRussian ? 'не указано' : 'not provided';
  String get unlabeledValue => isRussian ? 'без названия' : 'without label';
  String get connectTitle => isRussian ? 'Подключить' : 'Connect';
  String get connectSubtitle =>
      isRussian ? 'Нативный bridge позже' : 'Native bridge next';
  String get runtimeTitle => isRussian ? 'Runtime-конфиг' : 'Runtime config';
  String get runtimeSubtitle =>
      isRussian ? 'Sing-box или Xray' : 'Sing-box or Xray';
  String get checkpointTitle =>
      isRussian ? 'Android-чекпоинт' : 'Android checkpoint';
  String get checkpointBody => isRussian
      ? 'Этот экран можно шлифовать здесь. Но `VpnService`, разрешения, фоновые процессы и lifecycle туннеля считаются готовыми только после проверки на Android.'
      : 'This screen can be polished here. But VpnService, permissions, background work, and tunnel lifecycle are only done after Android validation.';
  String get checkpointNow =>
      isRussian ? 'Сейчас: живой дизайн' : 'Now: live design';
  String get checkpointNowBody => isRussian
      ? 'Быстрый hot reload для интерфейса.'
      : 'Fast hot reload for UI.';
  String get checkpointLater =>
      isRussian ? 'Потом: Android VPN' : 'Later: Android VPN';
  String get checkpointLaterBody => isRussian
      ? 'Нативные API, permission flow и реальный tunnel runtime.'
      : 'Native APIs, permission flow, and real tunnel runtime.';
  String get checkpointRule =>
      isRussian ? 'Правило: без shortcut' : 'Rule: no shortcut';
  String get checkpointRuleBody => isRussian
      ? 'VPN-милестоуны закрываются только Android-проверкой.'
      : 'VPN milestones close only after Android validation.';
  String get stageTitle => isRussian ? 'Этапы запуска' : 'Delivery sequence';
  String get stageNowLabel => isRussian ? 'Сейчас' : 'Now';
  String get stageNowTitle =>
      isRussian ? 'Компактный экран' : 'Compact surface';
  String get stageNowBody => isRussian
      ? 'Один аккуратный экран без длинного скролла.'
      : 'One compact screen without long scrolling.';
  String get stageNextLabel => isRussian ? 'Дальше' : 'Next';
  String get stageNextTitle =>
      isRussian ? 'Сохранение профиля' : 'Profile storage';
  String get stageNextBody => isRussian
      ? 'Локально сохранить выбранную ссылку и состояние.'
      : 'Persist the selected link and local state.';
  String get stageAndroidLabel => 'Android';
  String get stageAndroidTitle =>
      isRussian ? 'Нативный VPN bridge' : 'Native VPN bridge';
  String get stageAndroidBody => isRussian
      ? 'VpnService, runtime-ядро и системные разрешения.'
      : 'VpnService, runtime core, and system permissions.';
  String get onlineState => isRussian ? 'Онлайн' : 'Online';
  String get offlineState => isRussian ? 'Оффлайн' : 'Offline';
  String get probingState => isRussian ? 'Проверка...' : 'Checking...';
  String get unsupportedProbeState =>
      isRussian ? 'Пинг на Android' : 'Ping on Android';
  String get unknownProbeState => isRussian ? 'Нет данных' : 'No data';
  String get sourceHint => isRussian
      ? 'Поддерживаются прямые VLESS и subscription-ссылки.'
      : 'Direct VLESS and subscription links are supported.';

  String vpnState(VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.idle:
        return isRussian ? 'Ожидание подключения' : 'Idle';
      case VpnConnectionState.connecting:
        return isRussian ? 'Подключение...' : 'Connecting...';
      case VpnConnectionState.connected:
        return isRussian ? 'VPN подключен' : 'Connected';
      case VpnConnectionState.disconnecting:
        return isRussian ? 'Отключение...' : 'Disconnecting...';
      case VpnConnectionState.error:
        return isRussian ? 'Ошибка подключения' : 'Connection error';
    }
  }

  String vpnDetail(VpnStatusSnapshot snapshot) {
    if (snapshot.detail == 'vpn_supported_only_on_android_or_ios') {
      return isRussian
          ? 'В Linux preview видно UI. Реальный VPN стартует только на Android/iOS.'
          : 'UI preview works on Linux. Real VPN starts only on Android/iOS.';
    }

    if (snapshot.statusText == 'permission_denied') {
      return isRussian
          ? 'Разрешение на VPN не выдано пользователем.'
          : 'The VPN permission was not granted.';
    }

    if (snapshot.statusText == 'connected') {
      return isRussian
          ? 'Туннель поднят через VLESS runtime.'
          : 'The tunnel is running through the VLESS runtime.';
    }

    if (snapshot.statusText == 'initializing') {
      return isRussian
          ? 'Инициализирую runtime и запрашиваю разрешение.'
          : 'Initializing the runtime and requesting permission.';
    }

    if (snapshot.statusText == 'switching_server') {
      return isRussian
          ? 'Переключаю туннель на выбранный сервер.'
          : 'Switching the tunnel to the selected server.';
    }

    if (snapshot.statusText == 'disconnecting') {
      return isRussian
          ? 'Останавливаю активный туннель.'
          : 'Stopping the active tunnel.';
    }

    if (snapshot.detail != null && snapshot.detail!.isNotEmpty) {
      return snapshot.detail!;
    }

    return isRussian
        ? 'Рабочая ссылка готова к запуску через приложение.'
        : 'The working link is ready to be started from the app.';
  }

  String primaryAction(
    VpnConnectionState state, {
    bool selectedConnectionActive = true,
  }) {
    switch (state) {
      case VpnConnectionState.idle:
      case VpnConnectionState.error:
        return isRussian ? 'Подключить VPN' : 'Connect VPN';
      case VpnConnectionState.connecting:
        return isRussian ? 'Отключить' : 'Disconnect';
      case VpnConnectionState.connected:
        if (!selectedConnectionActive) {
          return isRussian ? 'Переключить VPN' : 'Switch VPN';
        }
        return isRussian ? 'Отключить' : 'Disconnect';
      case VpnConnectionState.disconnecting:
        return isRussian ? 'Отключить' : 'Disconnect';
    }
  }

  String parseError(ImportLinkError error) {
    switch (error) {
      case ImportLinkError.emptyLink:
        return isRussian ? 'Вставьте VLESS-ссылку.' : 'Paste a VLESS link.';
      case ImportLinkError.invalidScheme:
        return isRussian
            ? 'Ожидается ссылка формата vless://... или https://...'
            : 'Expected a link in the vless://... or https://... format.';
      case ImportLinkError.missingUuid:
        return isRussian
            ? 'В ссылке нет UUID пользователя.'
            : 'The link does not contain a user UUID.';
      case ImportLinkError.missingEndpoint:
        return isRussian
            ? 'В ссылке должны быть хост и порт.'
            : 'The link must contain a host and port.';
      case ImportLinkError.remoteFetchFailed:
        return isRussian
            ? 'Не удалось загрузить удаленную ссылку.'
            : 'Failed to fetch the remote link.';
      case ImportLinkError.remoteUnsupportedApp:
        return isRussian
            ? 'Сервер вернул заглушку: этот subscription сейчас не поддерживает такой клиент.'
            : 'The server returned a placeholder: this subscription does not support this client yet.';
      case ImportLinkError.remoteDeviceLimitReached:
        return isRussian
            ? 'Сервер принял HWID, но лимит устройств для этой подписки уже исчерпан.'
            : 'The server accepted the HWID, but the device limit for this subscription has been reached.';
      case ImportLinkError.remoteNoSupportedConfig:
        return isRussian
            ? 'Удаленная ссылка открылась, но внутри нет поддерживаемого VLESS-конфига.'
            : 'The remote link opened, but it does not contain a supported VLESS config.';
    }
  }

  String latencyState(ServerLatencySnapshot snapshot) {
    switch (snapshot.state) {
      case ServerLatencyState.online:
        return onlineState;
      case ServerLatencyState.offline:
        return offlineState;
      case ServerLatencyState.probing:
        return probingState;
      case ServerLatencyState.unsupported:
        return unsupportedProbeState;
      case ServerLatencyState.unknown:
        return unknownProbeState;
    }
  }

  String latencyValue(ServerLatencySnapshot snapshot) {
    if (snapshot.pingMs != null) {
      return '${snapshot.pingMs} ms';
    }

    return latencyState(snapshot);
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales.any(
    (Locale item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<AppStrings> load(Locale locale) async {
    return AppStrings._(locale);
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
