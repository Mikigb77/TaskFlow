// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get reviewSchedule => 'Data i hora';

  @override
  String get reviewChooseDate => 'Tria una data abans d’afegir una hora.';

  @override
  String get chooseAmPm => 'Tria a. m. o p. m.';

  @override
  String get reviewInvalidTime => 'Revisa aquest valor';

  @override
  String get reviewOptions => 'Més opcions';

  @override
  String get reviewOriginal => 'Veure què he dit';

  @override
  String get reviewOriginalText => 'Text original';

  @override
  String get reviewRemove => 'Treure d’aquesta captura';

  @override
  String get reviewRemoved => 'Esborrany retirat';

  @override
  String get reviewUndoSaved => 'Les tasques han tornat als esborranys.';

  @override
  String get reviewUndoChanged =>
      'Aquesta tasca ha canviat. S’han conservat les tasques desades.';

  @override
  String get reviewRepair => 'Corregir el text';

  @override
  String get reviewRepairHelp =>
      'Aquest text pot tenir accents malmesos. Revisa la correcció abans de desar.';

  @override
  String get reviewConfirmDetail => 'Així està bé';

  @override
  String get reviewNoTime => 'Sense hora';

  @override
  String get reviewEditDetail => 'Canviar aquesta dada';

  @override
  String get reviewResolved => 'Revisat';

  @override
  String get reviewResolve => 'Revisa aquesta dada';

  @override
  String get languageNativeName => 'Català';

  @override
  String sharingProblem(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'alreadyMember':
          'Aquesta persona ja hi té accés. Gestiona’n el rol a Persones.',
      'memberLimit':
          'Aquest projecte admet fins a 20 membres i 20 invitacions pendents. Primer elimina algú o revoca una invitació.',
      'accepted':
          'Aquesta invitació ja s’ha acceptat. Gestiona l’accés de la persona a Persones.',
      'owner':
          'El propietari no pot sortir. Pots suprimir el projecte si ja no la necessites.',
      'expired':
          'Aquesta invitació ja no està disponible. Demana’n una de nova al propietari.',
      'code': 'Demana al propietari del projecte el codi d’invitació actual.',
      'refresh':
          'Aquest projecte ha canviat. Actualitza-la abans de suprimir-la.',
      'ownerOnly':
          'Només el propietari pot gestionar els detalls i l’accés al projecte.',
      'other':
          'Només tens accés de lectura a aquest projecte. Demana al propietari permís per editar.',
    });
    return '$_temp0';
  }

  @override
  String syncProblem(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'assignmentChanged':
          'La persona responsable ha canviat. La teva edició pendent s’ha desat com a còpia personal.',
      'listConflict':
          'Un projecte ha canviat en un altre dispositiu. Tria quina versió vols conservar a Projectes.',
      'readOnly':
          'Aquest projecte ara és de només lectura. El canvi pendent s’ha conservat com a còpia personal.',
      'accessChanged':
          'L’accés a un projecte compartida ha canviat. Actualitza per acabar de sincronitzar els canvis permesos.',
      'taskConflict':
          'Una tasca ha canviat en un altre dispositiu. El teu canvi s’ha conservat com a còpia local i s’ha cancel·lat una supressió en conflicte.',
      'serverUpdate':
          'Actualitza aquest servidor abans de sincronitzar notes. Les notes es conserven en aquest telèfon.',
      'other':
          'El servidor no ha conservat aquest tipus de contingut. La còpia local es conserva.',
    });
    return '$_temp0';
  }

  @override
  String requestError(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'signOutFirst': 'Tanca la sessió abans de canviar de servidor.',
      'https': 'Utilitza una adreça de servidor HTTPS en aquesta versió.',
      'serverAddress':
          'Introdueix una adreça de servidor vàlida, com ara https://el-teu-servidor.example.',
      'emailUsed':
          'Ja existeix un compte amb aquest correu. Inicia la sessió o recupera la contrasenya.',
      'email': 'Introdueix una adreça de correu vàlida.',
      'credentials':
          'El correu o la contrasenya són incorrectes. Torna-ho a provar.',
      'session':
          'Torna a iniciar la sessió per continuar. Les tasques locals es conserven.',
      'accountChanged':
          'El compte ha canviat. Torna a obrir aquesta pantalla i prova-ho de nou.',
      'password':
          'Tria una contrasenya de 12 a 128 caràcters que no sigui habitual, només numèrica ni semblant al teu correu.',
      'recoveryCode':
          'El codi de recuperació no és vàlid o ha caducat. Demana’n un de nou.',
      'forbidden':
          'Aquest compte no pot fer aquesta acció. Revisa els permisos.',
      'rateLimit':
          'Hi ha massa peticions. Espera una mica abans de tornar-ho a provar.',
      'fileLimit': 'Tria un fitxer no buit de fins a 6 MiB.',
      'fileChanged':
          'El fitxer ha canviat o no s’ha pogut verificar. Tria’l de nou o torna’l a baixar.',
      'network':
          'No hi ha connexió. Revisa la wifi o les dades mòbils i torna-ho a provar.',
      'networkKept':
          'No hi ha connexió. Revisa la wifi o les dades mòbils i torna-ho a provar. Les tasques continuen desades en aquest telèfon.',
      'unavailable':
          'El servei no està disponible. Torna-ho a provar més endavant.',
      'validation':
          'No s’han acceptat algunes dades. Revisa la informació i torna-ho a provar.',
      'other': 'No s’ha pogut completar la petició. Torna-ho a provar.',
      'otherKept':
          'No s’ha pogut completar la petició. Torna-ho a provar. Les tasques continuen desades en aquest telèfon.',
    });
    return '$_temp0';
  }

  @override
  String get languageAutomatic => 'Utilitza l’idioma del telèfon';

  @override
  String get languageHelp =>
      'Utilitza el primer idioma disponible de les preferències del telèfon o tria’n un aquí. Si no n’hi ha cap de disponible, TaskFlow utilitza l’anglès. La tria es desa en aquest dispositiu.';

  @override
  String languageFollowing(String language) {
    return 'Idioma del telèfon · $language';
  }

  @override
  String get regionalFormats => 'Hora i regió';

  @override
  String get regionalFormatsHelp =>
      'Rellotge, primer dia de la setmana i fus horari de captura';

  @override
  String get sharedCaptureRetained =>
      'La captura compartida s’ha conservat. Torna a obrir TaskFlow per tornar-ho a provar.';

  @override
  String get note => 'Nota';

  @override
  String get noteEmptyBody => 'No s’hi ha afegit text.';

  @override
  String get fileNone => 'No hi ha fitxers adjunts.';

  @override
  String get newNote => 'Nota nova';

  @override
  String get editNote => 'Edita la nota';

  @override
  String get noteTitle => 'Títol de la nota';

  @override
  String get noteBody => 'La teva nota';

  @override
  String get notesHelp =>
      'Desa informació, idees i material de consulta. Utilitza una tasca per a allò que hagis de fer.';

  @override
  String get notesEmpty => 'Un espai per a les teves idees';

  @override
  String get notesEmptyHelp =>
      'Escriu o dicta una nota. Afegeix-hi enllaços o una llista de passos si et cal.';

  @override
  String get findNote => 'Cerca notes';

  @override
  String get saveNote => 'Desa la nota';

  @override
  String get noteSaved => 'Nota desada';

  @override
  String get recordNote => 'Dicta una nota';

  @override
  String get noteHint => 'Idees, detalls de reunions, enllaços útils…';

  @override
  String get noteTitleHint => 'p. ex., Contrasenya del wifi';

  @override
  String get noteTitleRequired => 'Posa un títol a la nota';

  @override
  String get noteNoMatches => 'No hi ha notes que coincideixin';

  @override
  String get notesSavedOnDevice => 'Les notes continuen en aquest telèfon.';

  @override
  String get allNotes => 'Totes les notes';

  @override
  String get deleteNoteQuestion => 'Vols suprimir aquesta nota?';

  @override
  String get keepNote => 'Conserva la nota';

  @override
  String get viewOnlyNote =>
      'Nota de només lectura. El propietari del projecte gestiona els permisos d’edició.';

  @override
  String get linkOpenError =>
      'No s’ha pogut obrir aquest enllaç. El pots copiar de la nota.';

  @override
  String get noteLinks => 'Enllaços';

  @override
  String get plannedFor => 'Planificada per a';

  @override
  String get plannedForHelp =>
      'Quan tens previst fer aquesta tasca. Pots establir un termini a Més detalls.';

  @override
  String get planning => 'Durada i termini';

  @override
  String get duration => 'Durada';

  @override
  String get durationUnset => 'Sense durada';

  @override
  String get durationEstimateHelp =>
      'És una estimació fins que triïs una hora d’inici.';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get durationInput => 'Minuts (1–1440)';

  @override
  String get durationInvalid => 'Introdueix un nombre enter de l’1 al 1440.';

  @override
  String get removeDuration => 'Treu la durada';

  @override
  String get deadline => 'Termini';

  @override
  String get deadlineUnset => 'Sense termini';

  @override
  String get deadlineHelp =>
      'Cal acabar-la abans d’aquesta data. Canviar l’inici planificat manté aquest termini.';

  @override
  String get deadlineTime => 'Hora límit';

  @override
  String get deadlineEndDay => 'Abans que acabi el dia';

  @override
  String get removeDeadline => 'Treu el termini';

  @override
  String get deadlineRecurringHelp =>
      'Aquest termini es repeteix amb cada repetició original. Moure una repetició manté el seu termini; canviar l’inici de la sèrie manté el primer termini i modifica l’interval dels següents.';

  @override
  String get deadlineLatePlan =>
      'Aquesta planificació acaba després del termini. Revisa l’inici o la durada.';

  @override
  String get deadlineOverdue => 'Termini vençut';

  @override
  String deadlineLabel(String date) {
    return 'Termini: $date';
  }

  @override
  String get reminderAnchor => 'Recorda-m’ho respecte de';

  @override
  String get reminderAnchorHelp =>
      'Un recordatori per repetició, segons la data seleccionada aquí.';

  @override
  String get dayTimeline => 'Horari del dia';

  @override
  String get timelineFirstPlan => 'Ves al primer element amb hora';

  @override
  String get timelineLimit =>
      'Es mostren els primers 200 elements amb hora. Utilitza l’agenda per veure totes les tasques.';

  @override
  String get timelineHelp =>
      'Tasques planificades i esdeveniments del telèfon. Els terminis indiquen quan cal haver acabat una tasca.';

  @override
  String get timelineUnblocked => 'Sense franja horària';

  @override
  String get timelineNoBlocks =>
      'No hi ha cap pla amb hora per a aquest dia. Afegeix una hora d’inici i una durada per reservar una franja.';

  @override
  String get timelinePoint => 'Sense durada · només hora';

  @override
  String get timelineShortBlocks =>
      'Els esdeveniments curts tenen una àrea tàctil més gran; la barra de color mostra la durada real.';

  @override
  String timelineHours(int hours) {
    return '$hours hores en aquest dia';
  }

  @override
  String get deviceCalendars => 'Calendaris del telèfon';

  @override
  String get deviceCalendarHelp =>
      'Mostra els esdeveniments dels calendaris del telèfon al costat de les tasques.';

  @override
  String get deviceCalendarPrivacy =>
      'Tria quins calendaris vols mostrar. Els esdeveniments són de només lectura a TaskFlow i es queden en aquest dispositiu; no es pugen ni s’envien a la IA. Gestiona’n els recordatoris a l’aplicació de calendari.';

  @override
  String get calendarEnable => 'Connecta els calendaris del telèfon';

  @override
  String get calendarDisable => 'Amaga els esdeveniments';

  @override
  String get calendarChoose => 'Tria els calendaris';

  @override
  String get calendarChooseHelp =>
      'Selecciona fins a 50 calendaris. Les hores segueixen el fus del dispositiu; els esdeveniments de tot el dia mantenen la data original.';

  @override
  String get calendarDenied =>
      'Permet l’accés al calendari per mostrar els esdeveniments. Les tasques continuen funcionant sense aquest permís.';

  @override
  String get calendarBlocked =>
      'L’accés al calendari està desactivat. El pots activar a la configuració de l’aplicació del telèfon.';

  @override
  String get calendarUnsupported =>
      'La visualització dels calendaris del telèfon està disponible a Android.';

  @override
  String get calendarSettings => 'Obre la configuració de l’aplicació';

  @override
  String get calendarEmptySources =>
      'No hi ha calendaris visibles sincronitzats amb aquest telèfon. Connecta un compte a l’aplicació de calendari i actualitza aquesta pantalla.';

  @override
  String get calendarRefresh => 'Actualitza els calendaris';

  @override
  String get calendarClear => 'Esborra la selecció';

  @override
  String get calendarReadError =>
      'No s’han pogut llegir els esdeveniments. Actualitza per tornar-ho a provar; pot ser que faltin compromisos en aquesta vista.';

  @override
  String get calendarReadRetry =>
      'No s’han pogut llegir els esdeveniments. Toca per tornar-ho a provar.';

  @override
  String get changeView => 'Canvia la vista';

  @override
  String get calendarPreferenceError =>
      'No s’ha pogut desar la selecció de calendaris. Torna-ho a provar. Pots seleccionar fins a 50 calendaris.';

  @override
  String get calendarTruncated =>
      'Hi ha massa esdeveniments per mostrar-los tots. Selecciona menys calendaris per veure els que falten.';

  @override
  String get calendarEvents => 'Esdeveniments del calendari';

  @override
  String get calendarReadOnly => 'Esdeveniment del calendari · només lectura';

  @override
  String get calendarNoSelection =>
      'Tria calendaris per veure els compromisos que ja tens.';

  @override
  String get calendarAllDay => 'Tot el dia';

  @override
  String calendarEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count esdeveniments',
      one: '1 esdeveniment',
    );
    return '$_temp0';
  }

  @override
  String get calendarOffline =>
      'Sense connexió: les tasques estan desades en aquest telèfon.';

  @override
  String get calendarUntitled => 'Esdeveniment sense títol';

  @override
  String get calendarOpenEvent => 'Obre a l’aplicació de calendari';

  @override
  String get calendarOpenError =>
      'L’aplicació de calendari no ha pogut obrir aquest esdeveniment.';

  @override
  String get calendarEventGone =>
      'Aquest esdeveniment ja no està disponible als calendaris seleccionats.';

  @override
  String get noScheduledTasks => 'No hi ha tasques de TaskFlow planificades';

  @override
  String get calendar => 'Calendari';

  @override
  String get tasks => 'Tasques';

  @override
  String get settings => 'Configuració';

  @override
  String get inbox => 'Safata d’entrada';

  @override
  String inboxCount(int count) {
    return 'Safata d’entrada · $count';
  }

  @override
  String get today => 'Avui';

  @override
  String get tomorrow => 'Demà';

  @override
  String get all => 'Totes';

  @override
  String get upcoming => 'Properes';

  @override
  String get completed => 'Completades';

  @override
  String get noDate => 'Sense data';

  @override
  String get anyTime => 'Sense hora';

  @override
  String get addTime => 'Afegeix una hora';

  @override
  String get removeDate => 'Treu la data';

  @override
  String get newTask => 'Tasca nova';

  @override
  String get editTask => 'Edita la tasca';

  @override
  String get taskDetails => 'Detalls de la tasca';

  @override
  String get sayTask => 'Dicta una tasca';

  @override
  String get typeTasks => 'Escriu tasques';

  @override
  String get unfinishedCaptures => 'Captures pendents';

  @override
  String get captureDiagnostics => 'Diagnòstic de captures';

  @override
  String get lists => 'Projectes';

  @override
  String get labels => 'Etiquetes';

  @override
  String get noList => 'Safata personal';

  @override
  String get priority => 'Prioritat';

  @override
  String get low => 'Baixa';

  @override
  String get medium => 'Mitjana';

  @override
  String get high => 'Alta';

  @override
  String get schedule => 'Planificació';

  @override
  String get date => 'Data';

  @override
  String get time => 'Hora';

  @override
  String get repeat => 'Repetició';

  @override
  String get neverRepeat => 'No es repeteix';

  @override
  String get daily => 'Cada dia';

  @override
  String get weekly => 'Cada setmana';

  @override
  String get monthly => 'Cada mes';

  @override
  String get yearly => 'Cada any';

  @override
  String get noEndDate => 'Sense data de finalització';

  @override
  String get notes => 'Notes';

  @override
  String get addNotes => 'Afegeix notes';

  @override
  String get attachments => 'Fitxers adjunts';

  @override
  String get checklist => 'Projecte de passos';

  @override
  String get complete => 'Completa';

  @override
  String get reopen => 'Torna a obrir';

  @override
  String get reschedule => 'Reprograma';

  @override
  String get undo => 'Desfés';

  @override
  String get cancel => 'Cancel·la';

  @override
  String get save => 'Desa';

  @override
  String get delete => 'Suprimeix';

  @override
  String get keepChanges => 'Conserva els canvis';

  @override
  String get createTask => 'Crea la tasca';

  @override
  String get saveChanges => 'Desa els canvis';

  @override
  String get taskTitle => 'Títol de la tasca';

  @override
  String get additionalNotes => 'Notes addicionals';

  @override
  String get moreDetails => 'Més detalls';

  @override
  String get fewerDetails => 'Menys detalls';

  @override
  String get appearance => 'Aparença';

  @override
  String get chooseAppearance => 'Tria l’aparença';

  @override
  String get appearanceHelp => 'Tria el teu estil o segueix el del dispositiu.';

  @override
  String get light => 'Clar';

  @override
  String get dark => 'Fosc';

  @override
  String get system => 'Sistema';

  @override
  String get yourSpace => 'El teu espai';

  @override
  String get welcomeSettings => 'Com a casa';

  @override
  String get notifications => 'Notificacions';

  @override
  String get notificationsHelp =>
      'Preferències dels recordatoris i avisos propers';

  @override
  String get accountBackup => 'Compte i còpia de seguretat';

  @override
  String get completedTasks => 'Tasques completades';

  @override
  String get progressHelp => 'Un petit registre del teu progrés';

  @override
  String get exportImport => 'Exporta i importa';

  @override
  String get exportImportHelp =>
      'Còpies de TaskFlow i migració de CSV de Todoist';

  @override
  String get regionalSettings => 'Idioma i regió';

  @override
  String get regionalSettingsHelp =>
      'Idioma, rellotge, inici de setmana i fus horari de captura';

  @override
  String get language => 'Idioma';

  @override
  String get deviceDefault => 'Segueix el dispositiu';

  @override
  String get clockFormat => 'Format de l’hora';

  @override
  String get clock12 => 'Rellotge de 12 hores';

  @override
  String get clock24 => 'Rellotge de 24 hores';

  @override
  String get weekStart => 'Primer dia de la setmana';

  @override
  String get monday => 'Dilluns';

  @override
  String get sunday => 'Diumenge';

  @override
  String get saturday => 'Dissabte';

  @override
  String get captureTimezone => 'Fus horari de captura';

  @override
  String get timezoneHelp =>
      'S’utilitza per interpretar les dates de les captures noves. Les tasques i captures pendents conserven la planificació. Les hores es mostren segons el fus horari del dispositiu.';

  @override
  String get searchTimezone => 'Cerca un fus horari';

  @override
  String get regionHelp =>
      'Aquestes preferències es queden en aquest dispositiu. Canviar-les no modifica les dates ni les hores desades de les tasques.';

  @override
  String get preferenceError =>
      'No s’ha pogut desar aquesta preferència. Torna-ho a provar.';

  @override
  String timezoneFallback(String zone) {
    return 'El fus horari del dispositiu no està disponible. Les captures noves utilitzaran $zone.';
  }

  @override
  String get week => 'Setmana';

  @override
  String get month => 'Mes';

  @override
  String get day => 'Dia';

  @override
  String get previousPeriod => 'Mes o setmana anterior';

  @override
  String get nextPeriod => 'Mes o setmana següent';

  @override
  String get moreClarity => 'Més claredat. Més espai per viure.';

  @override
  String get licenses => 'Llicències de codi obert';

  @override
  String get todayAgenda => 'L’agenda d’avui';

  @override
  String get breathingRoom => 'Una mica d’espai per respirar.';

  @override
  String get loadTasksError => 'No s’han pogut carregar les tasques';

  @override
  String get refreshCalendar => 'Prova d’actualitzar el calendari.';

  @override
  String get tryAgain => 'Torna-ho a provar';

  @override
  String get rememberPrompt => 'Què t’agradaria recordar?';

  @override
  String get calendarEmpty =>
      'Toca Dicta una tasca per parlar o Tasca nova per escriure. Les dates són opcionals; les tasques sense data van a la safata d’entrada.';

  @override
  String get planTask => 'Planifica una tasca';

  @override
  String get homeCapture => 'Captura des de la pantalla d’inici';

  @override
  String get homeCaptureHelp =>
      'Giny de micròfon, dreceres i text compartit a Android';

  @override
  String get homeCaptureInstructions =>
      'A Android, mantén premuda la icona de TaskFlow per veure les dreceres de captura o afegeix el giny Dicta una tasca des de la pantalla d’inici. També pots compartir text amb TaskFlow des d’una altra aplicació.';

  @override
  String get widgetPickerHelp =>
      'Afegeix el giny de TaskFlow des del selector de ginys de la pantalla d’inici.';

  @override
  String get signInHelp =>
      'Inicia la sessió per tenir les tasques sempre amb tu';

  @override
  String get diagnosticsHelp =>
      'Temps i comptadors locals, sense les teves paraules';

  @override
  String get appearanceError =>
      'No s’ha pogut desar la preferència d’aparença.';

  @override
  String get appearanceChangedError =>
      'S’ha canviat l’aparença, però no s’ha pogut desar la preferència en aquest dispositiu.';

  @override
  String get switchLight => 'Canvia al mode clar';

  @override
  String get switchDark => 'Canvia al mode fosc';

  @override
  String get list => 'Projecte';

  @override
  String get archivedList => 'Projecte arxivat';

  @override
  String get yourList => 'El teu projecte';

  @override
  String get yourTasks => 'Les teves tasques';

  @override
  String get everythingToDo => 'Tot allò que vols fer';

  @override
  String get noDateNeeded => 'No cal posar-hi data';

  @override
  String get findTask => 'Cerca una tasca…';

  @override
  String get allTasks => 'Totes les tasques';

  @override
  String get highPriority => 'Prioritat alta';

  @override
  String get filterLabel => 'Filtra per etiqueta';

  @override
  String get allLabels => 'Totes les etiquetes';

  @override
  String get noMatches => 'No hi ha tasques que coincideixin';

  @override
  String get freshStart => 'Un nou començament';

  @override
  String get differentFilter => 'Prova una altra paraula o un altre filtre.';

  @override
  String get listEmpty =>
      'Afegeix una tasca a aquest projecte. Tu tries la data i el recordatori.';

  @override
  String get tasksEmpty =>
      'Utilitza Dicta una tasca per parlar o Tasca nova per escriure.\nAfegeix-hi una data ara o deixa-la per a més endavant.';

  @override
  String get inboxEmpty =>
      'Desa-hi idees i coses per fer fins que en triïs la data.\nComença amb Dicta una tasca o Tasca nova.';

  @override
  String get savedOnDevice => 'Les tasques desades continuen al dispositiu.';

  @override
  String get checkCaptures => 'Revisa les captures pendents';

  @override
  String get createTaskTooltip => 'Crea una tasca';

  @override
  String get reviewTask => 'Revisa la tasca';

  @override
  String get fineTunePlan => 'Ajusta el teu pla.';

  @override
  String get onYourMind => 'Què tens al cap?';

  @override
  String get wordsPlan => 'Les teves paraules, un pla clar.';

  @override
  String get seriesEdits => 'Els canvis s’apliquen a tota la tasca periòdica.';

  @override
  String get giveName => 'Posa-hi un nom. Afegeix-hi una data quan vulguis.';

  @override
  String get checkBeforeAdd =>
      'Revisa els detalls abans d’afegir-la al calendari.';

  @override
  String get titleRequired => 'Introdueix un títol per a la tasca.';

  @override
  String get nameTask => 'Què t’agradaria fer?';

  @override
  String get reminder => 'Recordatori';

  @override
  String get off => 'Desactivat';

  @override
  String get dateForReminder => 'Afegeix una data per utilitzar un recordatori';

  @override
  String get chooseAlertTime => 'Tria l’hora de l’avís';

  @override
  String get reminderDefaultsError =>
      'No s’han pogut carregar els recordatoris per defecte. Revisa la configuració de notificacions.';

  @override
  String get loadingReminders =>
      'S’està carregant la configuració dels recordatoris…';

  @override
  String get repeatInterval => 'Interval de repetició';

  @override
  String get repeatOn => 'Es repeteix els';

  @override
  String get repeatUsesStart =>
      'S’utilitza el dia de la setmana de la data d’inici.';

  @override
  String get intervalRange => 'Tria un nombre de l’1 al 99.';

  @override
  String get removeEndDate => 'Treu la data de finalització';

  @override
  String get days => 'dies';

  @override
  String get weeks => 'setmanes';

  @override
  String get months => 'mesos';

  @override
  String get years => 'anys';

  @override
  String get deleteTask => 'Suprimeix la tasca';

  @override
  String get deleteTaskQuestion => 'Vols suprimir la tasca?';

  @override
  String get keepTask => 'Conserva la tasca';

  @override
  String get deleteTaskError =>
      'No s’ha pogut suprimir aquesta tasca. Torna-ho a provar.';

  @override
  String get attachmentUnavailable =>
      'Aquest fitxer adjunt no està disponible en aquest dispositiu.';

  @override
  String get attachmentOpenError => 'No s’ha pogut obrir aquest fitxer adjunt.';

  @override
  String get taskUnavailable => 'Tasca no disponible';

  @override
  String get occurrenceChanged => 'Repetició modificada';

  @override
  String get taskRemoved => 'És possible que aquesta tasca s’hagi suprimit.';

  @override
  String get occurrenceSkipped =>
      'Aquesta data s’ha omès o ja no forma part de la planificació periòdica.';

  @override
  String get editRepeating => 'Edita la tasca periòdica';

  @override
  String get nextStep => 'El teu pas següent';

  @override
  String get moveError =>
      'No s’ha pogut moure aquesta tasca. Torna-ho a provar.';

  @override
  String get occurrence => 'Repetició';

  @override
  String get starts => 'Comença';

  @override
  String get inboxDate => 'Sense data · Safata d’entrada';

  @override
  String get updateReminderError =>
      'No s’ha pogut actualitzar el recordatori. Torna-ho a provar.';

  @override
  String get thisOccurrence => 'Aquesta repetició';

  @override
  String get wholeSeries => 'Tota la sèrie';

  @override
  String get skipOccurrence => 'Omet aquesta repetició';

  @override
  String get resetOccurrence => 'Restableix aquesta repetició';

  @override
  String get reset => 'Restableix';

  @override
  String get recordingKept => 'Gravació conservada en aquest telèfon';

  @override
  String get onDeviceTranscript => 'Transcripció en directe al dispositiu';

  @override
  String get onlineAudio => 'Àudio desat · transcripció en línia';

  @override
  String get speechLanguage => 'Idioma de la veu';

  @override
  String get onDeviceUnavailable =>
      'El reconeixement de veu local no està disponible per a aquest idioma en aquest dispositiu. Grava àudio per processar-lo en línia o escriu.';

  @override
  String get setUpSpeech => 'Configura el reconeixement de veu local';

  @override
  String get checkAgain => 'Torna a comprovar-ho';

  @override
  String get examplePlan =>
      'Metge divendres a les 17 h. Portar els resultats. També comprar cafè.';

  @override
  String get discard => 'Descarta';

  @override
  String get keep => 'Conserva';

  @override
  String get capturePrivacy =>
      'La transcripció en directe utilitza el reconeixement local quan està disponible; en aquest mode no es conserva l’àudio. L’extracció de tasques amb IA necessita internet i envia les teves paraules a Google. L’àudio desat es transcriu en línia. Les captures pendents es queden al telèfon fins que les desis o descartis.';

  @override
  String get lookRight => 'Tot correcte?';

  @override
  String get finalSay =>
      'Toca un detall per canviar-lo. Tu tens l’última paraula.';

  @override
  String get changePriority => 'Canvia la prioritat';

  @override
  String get changeRepeat => 'Canvia la repetició';

  @override
  String get confirmedDetails => 'He revisat aquesta tasca';

  @override
  String agendaCounts(int remaining, int done) {
    return '$remaining per fer · $done completades';
  }

  @override
  String overdueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Endarrerides · $count',
      one: 'Endarrerida · 1',
    );
    return '$_temp0';
  }

  @override
  String pendingCaptureCount(int count) {
    return 'Captures pendents · $count';
  }

  @override
  String listeningSeconds(String time) {
    return 'S’està escoltant · $time';
  }

  @override
  String repeatEvery(int interval, String unit) {
    return 'Cada $interval $unit';
  }

  @override
  String repeatEveryPrompt(String unit) {
    return 'Repeteix cada… $unit';
  }

  @override
  String untilDate(String date) {
    return 'Fins al $date';
  }

  @override
  String priorityValue(String priority) {
    return 'Prioritat $priority';
  }

  @override
  String get pickDate => 'Tria una data';

  @override
  String get typeTask => 'Escriu una tasca';

  @override
  String get addStepDialog => 'Afegeix un pas';

  @override
  String get editStep => 'Edita el pas';

  @override
  String get step => 'Pas';

  @override
  String get shortStep => 'Afegeix un pas breu.';

  @override
  String get keepStep => 'Conserva el pas';

  @override
  String get repeatingSteps =>
      'Aquests passos es repeteixen amb la tasca. Marca’ls des dels detalls de cada repetició.';

  @override
  String get moveUp => 'Mou amunt';

  @override
  String get moveDown => 'Mou avall';

  @override
  String get removeStep => 'Treu el pas';

  @override
  String get addChecklist => 'Afegeix una llista de passos';

  @override
  String get addStep => 'Afegeix un pas';

  @override
  String get listUnavailable => 'Projecte no disponible';

  @override
  String get archived => 'Arxivada';

  @override
  String get sharedProject => 'Compartit';

  @override
  String get taskReopened => 'Tasca reoberta';

  @override
  String get taskCompleted => 'Tasca completada';

  @override
  String get undoError => 'No s’ha pogut desfer. Torna-ho a provar.';

  @override
  String get taskUpdateError =>
      'No s’ha pogut actualitzar aquesta tasca. Torna-ho a provar.';

  @override
  String get occurrenceSkippedNotice => 'Repetició omesa';

  @override
  String get originalRestored => 'Data original restablerta';

  @override
  String get movedInbox => 'S’ha mogut a la safata d’entrada';

  @override
  String get scheduleChangedAgain =>
      'La planificació ha tornat a canviar. Obre la tasca per revisar-la.';

  @override
  String get scheduleError =>
      'No s’ha pogut canviar la planificació. Torna-ho a provar.';

  @override
  String get rescheduleRepeating => 'Reprograma la tasca periòdica';

  @override
  String get rescheduleTask => 'Reprograma la tasca';

  @override
  String get seriesRescheduleHelp =>
      'Canvia l’inici de la sèrie i restableix les dates mogudes o omeses. «Sense data» atura la repetició.';

  @override
  String get occurrenceRescheduleHelp =>
      'Les altres dates de la sèrie es mantenen.';

  @override
  String get restoreOriginal => 'Restableix la data original';

  @override
  String get progressSmall => 'El progrés comença amb petits passos';

  @override
  String get completedEmpty => 'Cada tasca que acabis tindrà un lloc aquí.';

  @override
  String get progressHeading => 'Mira tot el que has fet.';

  @override
  String get completedLoadError =>
      'No s’han pogut carregar les tasques completades';

  @override
  String get tryLater => 'Torna-ho a provar d’aquí a un moment.';

  @override
  String get suggestionApplied => 'S’ha aplicat la proposta de planificació';

  @override
  String get changeSeriesQuestion => 'Vols canviar la planificació periòdica?';

  @override
  String get changeSeriesHelp =>
      'Les dates mogudes o omeses es restabliran segons la planificació nova. Les dates completades es conservaran a l’historial.';

  @override
  String get keepEditing => 'Continua editant';

  @override
  String get resetSave => 'Restableix i desa';

  @override
  String get taskSavedInbox => 'Tasca desada a la safata d’entrada';

  @override
  String taskAddedOn(String date) {
    return 'Afegida al $date';
  }

  @override
  String get changesSaved => 'Canvis desats';

  @override
  String get taskSaveError =>
      'No s’ha pogut desar la tasca. Torna-ho a provar.';

  @override
  String get localAttachmentHelp =>
      'Els fitxers adjunts es queden en aquest telèfon. Iniciar la sessió recupera les tasques, però aquests fitxers no apareixeran en un altre dispositiu.';

  @override
  String get choosePhoto => 'Tria una foto';

  @override
  String get attachFile => 'Adjunta un fitxer';

  @override
  String get attachError =>
      'No s’ha pogut adjuntar aquest fitxer. Torna-ho a provar.';

  @override
  String get capturedWords => 'Capturat de les teves paraules';

  @override
  String get titleRequiredField => 'Introdueix un títol per a la tasca';

  @override
  String get keepAsTitle => 'Conserva-ho com a títol';

  @override
  String get ambiguousTimeHelp =>
      'Tria AM/PM o afegeix l’hora manualment. No s’ha deduït cap hora.';

  @override
  String get clearDate => 'Esborra la data';

  @override
  String get optionalTime => 'Hora (opcional)';

  @override
  String get resetDateHelp => 'Restableix una data i desa els canvis.';

  @override
  String get skipped => 'Omesa';

  @override
  String get theDetails => 'Els detalls';

  @override
  String get labelLimit =>
      'Utilitza fins a 10 etiquetes de menys de 33 caràcters cadascuna.';

  @override
  String get notesHint => 'Qualsevol cosa que vulguis recordar…';

  @override
  String get addAttachment => 'Afegeix un fitxer adjunt';

  @override
  String get localAttachments =>
      'Els fitxers adjunts es queden en aquest dispositiu.';

  @override
  String get saving => 'S’està desant…';

  @override
  String get saveChangesSentence => 'Desa els canvis';

  @override
  String useSchedule(String schedule) {
    return 'Utilitza $schedule';
  }

  @override
  String checklistCount(int done, int total) {
    return 'Passos · $done/$total';
  }

  @override
  String checklistSemantics(int done, int total) {
    return 'Projecte de passos, $done de $total completats';
  }

  @override
  String get useDefault => 'Utilitza el valor per defecte';

  @override
  String get atScheduledTime => 'A l’hora planificada';

  @override
  String get hourBefore => '1 hora abans';

  @override
  String get dayBefore => '1 dia abans';

  @override
  String get defaultChoice => 'per defecte';

  @override
  String minutesBefore(int minutes) {
    return '$minutes minuts abans';
  }

  @override
  String reminderValue(String value) {
    return 'Recordatori: $value';
  }

  @override
  String get fileLocal => 'Només en aquest dispositiu';

  @override
  String get fileQueued => 'Pendent de pujar';

  @override
  String get fileBackedUp => 'Còpia desada al compte';

  @override
  String get fileDownloadAvailable => 'Disponible per baixar';

  @override
  String get fileMissing => 'Fitxer no disponible en aquest dispositiu';

  @override
  String get fileRemovalPending => 'Supressió pendent';

  @override
  String get fileUpload => 'Puja';

  @override
  String get fileDownload => 'Baixa';

  @override
  String get fileOpen => 'Obre';

  @override
  String get fileRetry => 'Torna a provar la transferència';

  @override
  String get fileRemove => 'Treu el fitxer adjunt';

  @override
  String get fileRemoveQuestion => 'Vols treure aquest fitxer adjunt?';

  @override
  String get fileRemoveHelp =>
      'Es traurà de la tasca i, si s’ha pujat, dels altres dispositius quan se sincronitzin. El fitxer original no se suprimirà.';

  @override
  String get yourAccount => 'El teu compte';

  @override
  String get accountHeading => 'El teu petit espai.';

  @override
  String get backupHeading => 'Els teus plans, ben desats.';

  @override
  String get accountBackupHelp =>
      'Les tasques i notes es desen al telèfon i se’n fa una còpia al compte quan hi ha connexió. Els fitxers nous es pugen després de desar; consulta’n l’estat als detalls. Per pujar fitxers locals anteriors, toca Puja.';

  @override
  String get accountUpToDate => 'Les tasques i notes estan al dia.';

  @override
  String get syncNow => 'Sincronitza ara';

  @override
  String get importLocalItems => 'Importa tasques i notes locals';

  @override
  String get importLocalItemsQuestion =>
      'Vols importar les tasques i notes locals?';

  @override
  String importLocalItemsHelp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mou $count elements d’aquest telèfon al teu compte',
      one: 'Mou 1 element d’aquest telèfon al teu compte',
    );
    return '$_temp0 per fer-ne una còpia de seguretat. Els fitxers adjunts es queden al telèfon fins que triïs Puja als detalls.';
  }

  @override
  String get importItems => 'Importa';

  @override
  String get noLocalItems => 'No hi ha tasques ni notes locals per importar.';

  @override
  String itemsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'S’han importat $count elements.',
      one: 'S’ha importat 1 element.',
    );
    return '$_temp0';
  }

  @override
  String get connectionDetails => 'Detalls de connexió';

  @override
  String get signOut => 'Tanca la sessió';

  @override
  String get recoveryHeading => 'Recupera l’accés al teu compte.';

  @override
  String get registerHeading => 'Un espai per als teus plans.';

  @override
  String get signInHeading => 'Et donem la benvinguda de nou.';

  @override
  String get recoveryHelp =>
      'Demana un correu de recuperació i utilitza el codi per establir una contrasenya nova.';

  @override
  String get accountSignInHelp =>
      'Inicia sessió i tingues els teus plans a mà.';

  @override
  String get email => 'Correu electrònic';

  @override
  String get enterEmail => 'Introdueix el teu correu electrònic';

  @override
  String get recoveryCode => 'Codi de recuperació';

  @override
  String get recoveryCodeHelp => 'Deixa’l buit per demanar un correu.';

  @override
  String get newPassword => 'Contrasenya nova';

  @override
  String get password => 'Contrasenya';

  @override
  String get passwordHelp => 'Com a mínim 12 caràcters';

  @override
  String get passwordTooShort => 'Utilitza com a mínim 12 caràcters';

  @override
  String get showPassword => 'Mostra la contrasenya';

  @override
  String get hidePassword => 'Amaga la contrasenya';

  @override
  String get continueRecovery => 'Continua la recuperació';

  @override
  String get createAccount => 'Crea el compte';

  @override
  String get signIn => 'Inicia la sessió';

  @override
  String get alreadyHaveAccount => 'Ja tens un compte? Inicia la sessió';

  @override
  String get createAnAccount => 'Crea un compte';

  @override
  String get backToSignIn => 'Torna a l’inici de sessió';

  @override
  String get forgotPassword => 'Has oblidat la contrasenya?';

  @override
  String get accountGuestHelp =>
      'Inicia sessió per accedir a les teves tasques i notes.';

  @override
  String get connectionSettings => 'Configuració de connexió';

  @override
  String get backendAddress => 'Adreça del servidor';

  @override
  String get backendAddressHelp =>
      'Emulador: http://10.0.2.2:8088\nTelèfon: la IP local de l’ordinador a la mateixa xarxa Wi-Fi.';

  @override
  String get recoveryEmailRequested =>
      'Si aquest compte existeix, s’hi ha enviat un correu de recuperació.';

  @override
  String get passwordResetComplete =>
      'Contrasenya actualitzada. Inicia la sessió amb la contrasenya nova.';

  @override
  String get newList => 'Projecte nou';

  @override
  String get editList => 'Edita el projecte';

  @override
  String get listName => 'Nom';

  @override
  String get listNameHint => 'Feina, Personal, Compres…';

  @override
  String get listNameRequired => 'Posa un nom al projecte.';

  @override
  String get colorTeal => 'Verd blavós';

  @override
  String get colorBlue => 'Blau';

  @override
  String get colorViolet => 'Violeta';

  @override
  String get colorAmber => 'Ambre';

  @override
  String get colorRose => 'Rosa';

  @override
  String get saveList => 'Desa el projecte';

  @override
  String get listSaveError =>
      'No s’ha pogut desar aquest projecte. Torna-ho a provar.';

  @override
  String get listRestored => 'Projecte restaurat';

  @override
  String get listArchivedHelp => 'Projecte arxivat. El contingut es conserva.';

  @override
  String get listUpdateError =>
      'No s’ha pogut actualitzar aquest projecte. Torna-ho a provar.';

  @override
  String get chooseListDetails => 'Tria els detalls del projecte';

  @override
  String listConflictHelp(String local, String remote) {
    return 'Aquest telèfon: $local\n\nL’altre dispositiu: $remote\n\nEl contingut de les tasques i notes es mantindrà.';
  }

  @override
  String get later => 'Més endavant';

  @override
  String get useOtherDevice => 'Utilitza l’altre dispositiu';

  @override
  String get useThisPhone => 'Utilitza aquest telèfon';

  @override
  String get listResolveError =>
      'No s’ha pogut resoldre el conflicte d’aquest projecte. Torna-ho a provar.';

  @override
  String get retryLists => 'Torna a carregar els projectes';

  @override
  String get refreshLists => 'Actualitza projectes i invitacions';

  @override
  String get listsHelp =>
      'Un lloc per a cada part de la teva vida. Crea projectes personals o comparteix-los amb un grup.';

  @override
  String get listsEmptyTitle => 'Un espai per a cada part de la vida';

  @override
  String get listsEmptyHelp =>
      'Comença amb Feina, Personal o Compres. Pots moure les tasques quan vulguis.';

  @override
  String get roleOwner => 'Propietari';

  @override
  String get roleEditor => 'Editor';

  @override
  String get roleViewer => 'Lector';

  @override
  String sharedListRole(String role) {
    return '$role · compartida';
  }

  @override
  String get listConflict =>
      'Modificada en un altre dispositiu · tria els detalls';

  @override
  String get archivedListHelp =>
      'Arxivada · les tasques i notes continuen disponibles';

  @override
  String listItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasques i notes',
      one: '1 tasca o nota',
      zero: 'Sense tasques ni notes',
    );
    return '$_temp0';
  }

  @override
  String manageItem(String name) {
    return 'Gestiona $name';
  }

  @override
  String get restoreList => 'Restaura el projecte';

  @override
  String get archiveList => 'Arxiva el projecte';

  @override
  String get sharingAndPeople => 'Ús compartit i persones';

  @override
  String get chooseDetails => 'Tria els detalls';

  @override
  String get invitationCode => 'Codi d’invitació';

  @override
  String get invitationCodeHelp =>
      'Per unir-se calen aquest codi i el compte de TaskFlow convidat. Comparteix-lo només amb la persona destinatària. Substituir una invitació invalida el codi anterior.';

  @override
  String get accountChanged => 'El compte ha canviat.';

  @override
  String get copyCode => 'Copia el codi';

  @override
  String get done => 'Fet';

  @override
  String get sharingUpdateError =>
      'No s’ha pogut actualitzar l’ús compartit. Comprova la connexió i torna-ho a provar.';

  @override
  String get inviteToList => 'Convida a aquest projecte';

  @override
  String get inviteHelp =>
      'Totes les tasques, notes i fitxers d’aquest projecte seran visibles quan acceptin. Enviarem la invitació per correu i també apareixerà al seu compte de TaskFlow. Caduca en 7 dies.';

  @override
  String get inviteeEmail => 'Correu del seu compte';

  @override
  String get enterEmailAddress => 'Introdueix una adreça de correu electrònic.';

  @override
  String get access => 'Accés';

  @override
  String get sharingRolesHelp =>
      'Els editors poden afegir, modificar, completar i suprimir tasques i fitxers. Només el propietari gestiona el projecte i les persones. Les tasques compartides es queden en aquest projecte; exportar-les crea una còpia personal.';

  @override
  String get createInvitation => 'Crea la invitació';

  @override
  String get listSharing => 'Ús compartit del projecte';

  @override
  String get sharingLoadError => 'No s’ha pogut carregar l’ús compartit.';

  @override
  String get retry => 'Torna-ho a provar';

  @override
  String yourRole(String role) {
    return 'El teu rol: $role';
  }

  @override
  String get sharingHelp =>
      'Comparteix compres i tasques de casa. Els canvis se sincronitzen quan l’aplicació es connecta o quan actualitzes.';

  @override
  String get invitePerson => 'Convida una persona';

  @override
  String get people => 'Persones';

  @override
  String get noOtherMembers => 'De moment, només tu has acceptat l’accés.';

  @override
  String get makeEditor => 'Fes editor';

  @override
  String get makeViewer => 'Fes lector';

  @override
  String get removeAccess => 'Retira l’accés';

  @override
  String get removeAccessHelp =>
      'Aquesta persona perdrà l’accés al projecte i a les seves tasques, notes i fitxers. Els canvis compartits pendents d’enviar se suprimiran en la pròxima sincronització correcta.';

  @override
  String get pendingInvitations => 'Invitacions pendents';

  @override
  String pendingRole(String role) {
    return '$role · pendent';
  }

  @override
  String get revokeInvitation => 'Revoca la invitació';

  @override
  String get replaceInvitationHelp =>
      'Toca una invitació pendent per substituir-ne el codi.';

  @override
  String get howSharingWorks => 'Com funciona l’ús compartit';

  @override
  String get sharedDataHelp =>
      'Les tasques, notes i fitxers pujats es comparteixen. Els editors els poden canviar o suprimir; els lectors els poden consultar. Les opcions dels recordatoris es comparteixen, però cada telèfon ha d’activar les seves notificacions.';

  @override
  String get sharingRemovalHelp =>
      'Sortir del projecte o perdre-hi l’accés elimina les tasques, notes, canvis pendents i còpies baixades d’aquest telèfon en la pròxima sincronització correcta. Els dispositius sense connexió i les còpies ja exportades no es poden esborrar remotament.';

  @override
  String get deleteList => 'Suprimeix el projecte';

  @override
  String get deleteListHelp =>
      'Vols suprimir aquest projecte i totes les seves tasques, notes i fitxers pujats per a tothom? No es pot desfer.';

  @override
  String get deleteListForEveryone => 'Suprimeix el projecte per a tothom';

  @override
  String get leaveList => 'Surt del projecte';

  @override
  String get leaveListHelp =>
      'Les tasques, notes i fitxers compartits, i els canvis pendents d’enviar, se suprimiran d’aquest telèfon. Els altres membres conservaran el projecte.';

  @override
  String get enterInvitationCode => 'Introdueix el codi d’invitació';

  @override
  String get requestInvitationCodeHelp =>
      'Demana al propietari del projecte el codi que ha rebut en convidar-te.';

  @override
  String get invitationCodeRequired => 'Enganxa el codi d’invitació complet.';

  @override
  String get joinList => 'Uneix-te al projecte';

  @override
  String get invitationResponseError =>
      'No s’ha pogut respondre. Torna-ho a provar quan tinguis connexió.';

  @override
  String get retryInvitations => 'Torna a carregar les invitacions';

  @override
  String get invitations => 'Invitacions';

  @override
  String joinListHelp(String role) {
    return 'Uneix-t’hi com a $role. Les tasques, notes i fitxers pujats compartits se sincronitzaran amb el teu compte.';
  }

  @override
  String get acceptInvitation => 'Accepta la invitació';

  @override
  String get decline => 'Rebutja';

  @override
  String get fileEmpty => 'No hi ha fitxers adjunts. Afegeix-ne un en editar.';

  @override
  String get fileLoadError =>
      'No s’ha pogut carregar l’estat dels fitxers adjunts. Torna-ho a provar.';

  @override
  String get fileActionError =>
      'No s’ha pogut completar aquesta acció. La tasca està desada; torna-ho a provar.';

  @override
  String get fileSignInHelp =>
      'Inicia la sessió per pujar els fitxers i recuperar-los en un altre dispositiu.';

  @override
  String get fileUploadHelp =>
      'Els fitxers nous es pugen al compte després de desar: fins a 6 MiB cadascun i 64 MiB per compte. Els fitxers locals anteriors es queden al dispositiu fins que triïs Puja als detalls de la tasca.';

  @override
  String get fileLocalHelp =>
      'Els fitxers es queden en aquest dispositiu fins que iniciïs la sessió i triïs Puja als detalls de la tasca. Fins a 6 MiB per fitxer.';

  @override
  String get fileLimit =>
      'Tria un fitxer no buit de fins a 6 MiB. Pots adjuntar fins a 20 fitxers per tasca.';

  @override
  String get fileManageHelp =>
      'Obre els detalls de la tasca per baixar, pujar o treure fitxers adjunts del compte.';

  @override
  String get notificationLoadError =>
      'No s’ha pogut carregar la configuració de notificacions. Torna-ho a provar.';

  @override
  String get notificationSaveError =>
      'No s’ha pogut desar la configuració dels recordatoris. Torna-ho a provar.';

  @override
  String get enableReminders => 'Activa els recordatoris';

  @override
  String get noReminderTurnOn => 'Sense recordatori · Activa';

  @override
  String get exactAlarmsNeeded =>
      'Perquè l’avís arribi a l’hora, permet «Alarmes i recordatoris».';

  @override
  String get remindersOnConfirmation => 'Fet. Recordatoris activats.';

  @override
  String get reminderAskQuestion => 'Vols un recordatori abans?';

  @override
  String get reminderAskYes => 'Sí, recorda-m’ho';

  @override
  String get reminderAskNotNow => 'Ara no';

  @override
  String get details => 'Detalls';

  @override
  String get mobileNotificationsOnly => 'Notificacions només al mòbil';

  @override
  String get notificationPermissionOff =>
      'El permís del sistema està desactivat';

  @override
  String get preciseAlarmsAvailable =>
      'L’accés a alarmes exactes està disponible';

  @override
  String get approximateAlarmsHelp =>
      'Els avisos són aproximats fins que s’activa l’accés a alarmes exactes';

  @override
  String get openSystemSettings => 'Obre la configuració del sistema';

  @override
  String get allowPreciseAlarms => 'Permet «Alarmes i recordatoris»';

  @override
  String get taskDefaults => 'Valors per defecte de les tasques';

  @override
  String get timedTasks => 'Tasques amb hora';

  @override
  String get dateOnlyTasks => 'Tasques amb data sense hora';

  @override
  String get dailyCheckIns => 'Revisions diàries';

  @override
  String get dailyCheckInsHelp =>
      'Un petit recordatori per revisar les tasques actuals.';

  @override
  String get morningCheckIn => 'Al matí';

  @override
  String get eveningCheckIn => 'Al vespre';

  @override
  String get upcomingAlerts => 'Avisos propers';

  @override
  String get scheduledAlertHelp =>
      'Programat vol dir que el telèfon ha acceptat l’avís. Les restriccions de bateria, la configuració del sistema i l’aturada forçada poden retardar-lo o impedir-lo.';

  @override
  String get androidAlertRefreshHelp =>
      'El període s’actualitza en utilitzar l’aplicació i amb una tasca en segon pla cada hora, quan Android ho permet.';

  @override
  String get backgroundAlertRefreshHelp =>
      'El període s’actualitza en utilitzar l’aplicació i quan el sistema permet l’actualització en segon pla.';

  @override
  String get noUpcomingAlerts =>
      'No hi ha avisos propers. Tria un recordatori en una tasca amb data.';

  @override
  String get repeatsDaily => 'es repeteix cada dia';

  @override
  String get retryScheduling => 'Actualitza i torna a programar';

  @override
  String get alertPending => 'pendent';

  @override
  String get alertScheduled => 'programat';

  @override
  String get alertApproximate => 'aproximat';

  @override
  String get alertBlocked => 'bloquejat';

  @override
  String get alertFailed => 'ha fallat';

  @override
  String get alertInactive => 'inactiu';

  @override
  String get alertElapsed => 'passat';

  @override
  String get reminderPermissionError =>
      'Les notificacions estan desactivades a la configuració del sistema.';

  @override
  String get reminderScheduleError =>
      'El telèfon no ha pogut programar aquest avís. Torna-ho a provar des de Configuració.';

  @override
  String get reminderBackgroundError =>
      'L’actualització en segon pla no ha pogut acabar. Obre TaskFlow per tornar-ho a provar.';

  @override
  String get reminderBackgroundUnavailable =>
      'L’actualització automàtica en segon pla no està disponible. Els avisos s’actualitzen quan obres TaskFlow.';

  @override
  String get reminderActionError =>
      'No s’ha pogut completar una acció de notificació. Obre la tasca per tornar-ho a provar.';

  @override
  String get reminderSetupError =>
      'No s’ha pogut completar la configuració de notificacions. Torna-ho a provar des de Configuració.';

  @override
  String get reminderAccountError =>
      'No s’han pogut actualitzar els recordatoris del compte. Obre la configuració de notificacions per tornar-ho a provar.';

  @override
  String get reminderRefreshError =>
      'No s’han pogut actualitzar els recordatoris. Les tasques estan desades; torna-ho a provar des de la configuració de notificacions.';

  @override
  String get transferError =>
      'No s’ha pogut acabar. Les tasques i notes existents no han canviat. Torna-ho a provar.';

  @override
  String get exportSaved =>
      'Exportació desada. Conserva el fitxer en un lloc privat.';

  @override
  String get keepYourTasks => 'Porta les tasques amb tu.';

  @override
  String get archiveContentsHelp =>
      'Les exportacions de TaskFlow inclouen tasques, notes, planificacions, canvis de dates periòdiques, estat de compleció, passos, etiquetes i projectes personals. S’hi indiquen els noms dels fitxers adjunts; se n’exclouen el contingut, les credencials, les preferències del dispositiu i les captures pendents.';

  @override
  String get exportTaskFlowFile => 'Exporta un fitxer de TaskFlow';

  @override
  String get chooseImportFile => 'Tria un fitxer per importar';

  @override
  String get chooseImportFileHelp =>
      'Tria una exportació JSON de TaskFlow o un CSV de projecte de Todoist (fins a 32 MB i 5.000 tasques i notes). El podràs revisar abans d’importar-lo.';

  @override
  String get importPreview => 'Previsualització de la importació';

  @override
  String get importCopiesHelp =>
      'Les tasques i notes seleccionades i els projectes del fitxer s’afegeixen com a còpies personals. El contingut existent es conserva. Tornar a importar el mateix fitxer omet els registres ja importats en aquest telèfon; un fitxer modificat o exportat de nou compta com una importació diferent.';

  @override
  String get listsIncluded => 'Projectes inclosos';

  @override
  String get archivedPersonalCopy => 'Còpia personal arxivada';

  @override
  String get personalCopy => 'Còpia personal';

  @override
  String get alreadyImported => 'Ja s’ha importat en aquest telèfon';

  @override
  String get taskFlowExportSource => 'Exportació de TaskFlow';

  @override
  String get todoistCsvSource => 'CSV de projecte de Todoist';

  @override
  String deferredAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hi ha $count avisos posteriors',
      one: 'Hi ha 1 avís posterior',
    );
    return '$_temp0 fora del període actual. La pròxima actualització afegirà els primers que hi càpiguen.';
  }

  @override
  String turnOffReminder(String title) {
    return 'Desactiva $title';
  }

  @override
  String importResult(int items, int lists) {
    String _temp0 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items elements',
      one: '1 element',
    );
    String _temp1 = intl.Intl.pluralLogic(
      lists,
      locale: localeName,
      other: '$lists projectes',
      one: '1 projecte',
    );
    return 'S’han afegit $_temp0 i $_temp1.';
  }

  @override
  String importSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'S’han omès $count elements ja importats.',
      one: 'S’ha omès 1 element ja importat.',
    );
    return '$_temp0';
  }

  @override
  String importCounts(String source, int tasks, int notes, int lists) {
    return '$source · $tasks tasques · $notes notes · $lists projectes';
  }

  @override
  String cannotImport(String reason) {
    return 'No es pot importar: $reason';
  }

  @override
  String importSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elements seleccionats',
      one: '1 element seleccionat',
    );
    return 'Importa $_temp0 i els projectes';
  }

  @override
  String importRow(int row) {
    return 'Registre $row';
  }

  @override
  String get archiveFileTooLarge => 'Tria un fitxer de menys de 32 MB.';

  @override
  String get archiveUnsupportedArchive =>
      'No és una exportació de TaskFlow compatible (versions 1 i 2).';

  @override
  String get archiveInvalidList => 'Metadades de projecte no vàlides.';

  @override
  String get archiveDuplicateLists => 'Identificadors de projecte duplicats.';

  @override
  String get archiveInvalidListStyle =>
      'Color o estat d’arxiu del projecte no vàlid.';

  @override
  String get archiveInvalidTask => 'Registre de tasca no vàlid.';

  @override
  String get archiveDuplicateTask => 'Identificador de tasca duplicat.';

  @override
  String get archiveInvalidAttachments =>
      'Informació de fitxers adjunts no vàlida.';

  @override
  String get archiveMissingList =>
      'La tasca fa referència a un projecte que falta en aquest fitxer.';

  @override
  String get archiveInvalidTaskFields => 'Camps de tasca no vàlids.';

  @override
  String get archiveUnsupportedKind => 'Tipus de tasca o nota no compatible.';

  @override
  String get archiveInvalidCompletion => 'Estat de compleció no vàlid.';

  @override
  String get archiveTwoSchedules =>
      'Una tasca no pot tenir dues planificacions.';

  @override
  String get archiveTwoDeadlines =>
      'Tria un termini amb hora o només amb data.';

  @override
  String get archiveInvalidReminderDate =>
      'Tria una data disponible per al recordatori.';

  @override
  String get archiveUnsupportedRepeat => 'Regla de repetició no compatible.';

  @override
  String get archiveWeekdaysNeedWeekly =>
      'Triar dies de la setmana requereix una repetició setmanal.';

  @override
  String get archiveRepeatNeedsStart =>
      'Una tasca periòdica necessita una data d’inici.';

  @override
  String get archiveInvalidOccurrence => 'Canvi de repetició no vàlid.';

  @override
  String get archiveDuplicateOccurrence => 'Canvis de repetició duplicats.';

  @override
  String get archiveInvalidSkipped => 'Data omesa no vàlida.';

  @override
  String get archiveInvalidOccurrenceSchedule =>
      'Planificació de repetició no vàlida.';

  @override
  String get archiveRepeatSettingsNeedRepeat =>
      'Les opcions de repetició necessiten una tasca periòdica.';

  @override
  String get archiveRepeatUsesCompletedDates =>
      'Les tasques periòdiques utilitzen dates de compleció individuals.';

  @override
  String get archiveInvalidChecklist => 'Pas no vàlid.';

  @override
  String get archiveDuplicateChecklist => 'Identificadors de pas duplicats.';

  @override
  String get archiveInvalidChecklistProgress =>
      'Progrés de la llista de passos no vàlid.';

  @override
  String get archiveRepeatEndBeforeStart =>
      'La repetició acaba abans de començar.';

  @override
  String get archiveOccurrenceOutsideRepeat =>
      'Un canvi de data queda fora d’aquesta regla de repetició.';

  @override
  String get archiveExportTooLarge =>
      'Aquesta exportació supera el límit de 32 MB o de 5.000 tasques.';

  @override
  String get archiveInvalidDateFormat =>
      'Les dates han d’utilitzar el format YYYY-MM-DD.';

  @override
  String get archiveInvalidDate => 'Data del calendari no vàlida.';

  @override
  String get archiveMissingTimezone =>
      'Les dates amb hora necessiten una hora ISO i un desplaçament de fus horari.';

  @override
  String get archiveInvalidClock => 'Hora no vàlida.';

  @override
  String get archiveInvalidOffset => 'Desplaçament de fus horari no vàlid.';

  @override
  String get archiveInvalidTimedDate => 'Data amb hora no vàlida.';

  @override
  String get archiveFileUnreadable =>
      'No s’ha pogut llegir aquest fitxer. Tria’n una còpia local.';

  @override
  String get archiveEmptyCsv => 'Aquest CSV és buit.';

  @override
  String get archiveCsvHeader =>
      'Tria un CSV de projecte de Todoist amb les columnes TYPE i CONTENT.';

  @override
  String get archiveCsvTaskLimit =>
      'Tria un CSV amb un màxim de 5.000 tasques.';

  @override
  String get archiveCsvPriority => 'La prioritat ha de ser de l’1 al 4.';

  @override
  String get archiveCsvIndent => 'El nivell de sagnat ha de ser de l’1 al 4.';

  @override
  String get archiveCsvRecordLimit => 'Aquest CSV té massa registres.';

  @override
  String get archiveCsvQuoting =>
      'Les cometes del CSV no tenen un format vàlid.';

  @override
  String get archiveCsvUnclosedQuote =>
      'S’ha trobat un camp entre cometes sense tancar al CSV.';

  @override
  String get archiveNotesTooLong =>
      'La tasca i els comentaris superen els 8.000 caràcters de notes.';

  @override
  String get archiveInvalidFile => 'El fitxer no és JSON ni text UTF-8 vàlid.';

  @override
  String get archiveUnknownFields =>
      'S’ometran els camps de tasca no reconeguts.';

  @override
  String get archivePersonalCopies =>
      'Les importacions creen còpies personals noves. No s’hi inclouen l’accés al compte, els fitxers, les preferències de notificació ni les captures pendents.';

  @override
  String get archiveCsvPriorities =>
      'Les prioritats 3 i 4 de Todoist passen a Baixa. Les subtasques es converteixen en tasques independents.';

  @override
  String get archiveCsvDates =>
      'Només es planifiquen dates ISO i hores amb un desplaçament de fus horari explícit. Les altres expressions de data es conserven a les notes perquè les revisis.';

  @override
  String get archiveCsvPersonalCopies =>
      'Es creen còpies personals. No es transfereixen les assignacions, els fitxers ni els permisos d’ús compartit. Els CSV de projecte de Todoist poden ometre les tasques completades.';

  @override
  String get archiveReviewSchedule =>
      'Cal revisar la planificació original; aquesta tasca anirà a la safata d’entrada.';

  @override
  String get archiveFlattenedSubtasks =>
      'Les subtasques passaran a ser tasques independents.';

  @override
  String get archiveInlineLabels =>
      'Les @etiquetes del text es conserven al títol.';

  @override
  String archiveAttachmentsOmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No s’inclouen $count fitxers adjunts',
      one: 'No s’inclou 1 fitxer adjunt',
    );
    return '$_temp0.';
  }

  @override
  String archiveInvalidCollection(String field, int max) {
    return '$field: valor no vàlid (màxim $max).';
  }

  @override
  String archiveInvalidText(String field, int max) {
    return '$field: text no vàlid (màxim $max caràcters).';
  }

  @override
  String archiveInvalidInteger(String field, int min, int max) {
    return '$field: valor no vàlid ($min–$max).';
  }

  @override
  String archiveInvalidIdentifier(String field) {
    return '$field: identificador no vàlid.';
  }

  @override
  String archiveCsvExtraFields(int row) {
    return 'La fila $row té més camps que la capçalera.';
  }

  @override
  String archiveCsvInvalidSection(int row) {
    return 'Fila $row: el nom de secció no és vàlid; les seves tasques no tindran projecte.';
  }

  @override
  String archiveCsvListDescription(int row) {
    return 'Fila $row: les descripcions de projecte no són compatibles.';
  }

  @override
  String archiveCsvOrphanComment(int row) {
    return 'Fila $row: el comentari no té cap tasca anterior vàlida; s’ometrà.';
  }

  @override
  String archiveCsvUnsupportedRow(int row) {
    return 'Fila $row: tipus de registre no compatible; s’ometrà.';
  }

  @override
  String archiveCsvFieldInNotes(String field) {
    return '$field es conservarà com a text a les notes.';
  }

  @override
  String archiveField(String field) {
    String _temp0 = intl.Intl.selectLogic(field, {
      'export_id': 'export_id',
      'tasks': 'tasques',
      'lists': 'projectes',
      'list_id': 'identificador de projecte',
      'list_name': 'nom de projecte',
      'task_identifier': 'identificador de tasca',
      'title': 'títol',
      'notes': 'notes',
      'priority': 'prioritat',
      'duration': 'durada',
      'repeat_interval': 'interval de repetició',
      'repeat_weekdays': 'dies de repetició',
      'weekday': 'dia de la setmana',
      'completed_dates': 'dates completades',
      'individual_date_changes': 'canvis de data individuals',
      'list_identifier': 'identificador de projecte',
      'labels': 'etiquetes',
      'label': 'etiqueta',
      'checklist': 'llista de passos',
      'checklist_identifier': 'identificador de pas',
      'checklist_title': 'títol del pas',
      'checklist_dates': 'dates dels passos',
      'reminder_lead': 'antelació del recordatori',
      'reminder_time': 'hora del recordatori',
      'other': 'camp',
    });
    return '$_temp0';
  }

  @override
  String get notificationChannel => 'Recordatoris de tasques';

  @override
  String get notificationComplete => 'Completa';

  @override
  String get notificationSnooze => 'Ajorna 10 min';

  @override
  String get notificationDeadline => 'S’acosta el termini de la tasca.';

  @override
  String get notificationDue => 'És l’hora de la teva tasca.';

  @override
  String notificationInMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Planificada d’aquí a $minutes minuts.',
      one: 'Planificada d’aquí a 1 minut.',
    );
    return '$_temp0';
  }

  @override
  String get notificationToday => 'A la teva llista d’avui.';

  @override
  String get notificationMorning => 'Fes espai per a avui';

  @override
  String get notificationEvening => 'Un moment per fer balanç';

  @override
  String get notificationCheckIn =>
      'Obre TaskFlow per veure les tasques actuals i planificar el pas següent.';

  @override
  String get notificationSnoozed => 'La teva tasca ajornada.';

  @override
  String get captureGone => 'Aquesta captura ja no està disponible.';

  @override
  String get captureNoteLength =>
      'Una nota ha de tenir entre 1 i 8.000 caràcters.';

  @override
  String get captureNoTasks =>
      'No s’ha trobat cap tasca. La captura es conserva.';

  @override
  String get captureUnsupportedKind =>
      'Aquest servidor no admet el tipus de captura seleccionat. El contingut es conserva.';

  @override
  String get captureOffline =>
      'No es pot connectar amb el servidor. Revisa la connexió i l’adreça del servidor i torna-ho a provar.';

  @override
  String get captureTimeout =>
      'El servidor ha trigat massa a respondre. Pots tornar a provar aquesta captura.';

  @override
  String get captureUnavailable =>
      'El servei de processament no està disponible. Torna a provar aquesta captura més endavant.';

  @override
  String get captureAllowance =>
      'S’ha arribat al límit de peticions del servei. Torna-ho a provar més endavant.';

  @override
  String get captureSignIn =>
      'Torna a iniciar la sessió per processar la captura d’aquest compte.';

  @override
  String get captureForbidden =>
      'Aquest compte no pot processar la captura. Revisa els permisos i torna-ho a provar.';

  @override
  String get captureTooLarge =>
      'Aquesta gravació supera el límit del servei. Conserva-la per a més endavant o escriu una descripció més curta.';

  @override
  String get captureTypedFirst =>
      'Desa o descarta aquesta captura escrita abans de començar una gravació.';

  @override
  String get captureMicrophone =>
      'Permet l’accés al micròfon per gravar o escriu a sota.';

  @override
  String get captureMicrophoneBlocked =>
      'El micròfon està desactivat per a TaskFlow. Activa’l a Configuració o escriu.';

  @override
  String get captureOpenSettings => 'Obre Configuració';

  @override
  String get captureStarting => 'Un moment…';

  @override
  String get capturePaused => 'En pausa';

  @override
  String get captureListening => 'S’està escoltant';

  @override
  String get captureStartTalking => 'Comença a parlar';

  @override
  String get captureContinue => 'Continua';

  @override
  String get captureTypeInstead => 'Escriu';

  @override
  String get captureStillListening => 'Encara t’escolto. Toca Fet quan acabis.';

  @override
  String get captureTimeLeft => 'Queden 10 segons';

  @override
  String get captureKeepQuestion => 'Vols conservar el que has dit?';

  @override
  String get captureKeepHelp => 'Ho podràs acabar més tard.';

  @override
  String get captureRecordingFirst =>
      'Torna a provar aquesta gravació o descarta-la abans de gravar-ne una altra.';

  @override
  String get captureEmptyInput => 'Primer digues o escriu què has de fer.';

  @override
  String get captureSpeechStopped =>
      'El reconeixement de veu s’ha aturat. Les paraules conservades estan desades; grava àudio o escriu per continuar.';

  @override
  String get captureNoSpeech =>
      'No s’ha detectat veu clara. Les paraules conservades continuen disponibles.';

  @override
  String get captureSpeechLanguage =>
      'El reconeixement de veu local no està instal·lat per a aquest idioma. Tria un altre idioma, grava àudio o escriu.';

  @override
  String get captureSpeechUnavailable =>
      'El reconeixement de veu local no està disponible. Grava àudio o escriu.';

  @override
  String get captureSpeechBusy =>
      'Ja hi ha una petició de micròfon oberta. Acaba-la abans de tornar-ho a provar.';

  @override
  String get captureIncompleteAudio =>
      'L’àudio conservat és incomplet i no es pot processar. Es continua conservant en aquest telèfon.';

  @override
  String get captureWriteFailed =>
      'No s’ha pogut conservar aquest esborrany al telèfon. Torna-ho a provar abans de sortir.';

  @override
  String get captureStopFailed =>
      'No s’ha pogut acabar la gravació. El contingut conservat anteriorment es manté.';

  @override
  String get captureDiscardFailed =>
      'No s’ha pogut descartar aquesta captura. Es continua conservant.';

  @override
  String get captureReviewWriteFailed =>
      'No s’han pogut conservar aquests canvis. Torna-ho a provar abans de sortir.';

  @override
  String get captureSaveFailed =>
      'No s’ha pogut acabar de desar. La captura es conserva; tornar-ho a provar no duplicarà les tasques desades.';

  @override
  String get captureSetupRequested =>
      'S’ha demanat la configuració de veu. Segueix les indicacions d’Android i toca Torna a comprovar-ho. Mentrestant pots continuar escrivint.';

  @override
  String get captureSetupUnavailable =>
      'La configuració de veu no està disponible aquí. Utilitza àudio desat o escriu.';

  @override
  String get captureKept => 'La captura es conserva en aquest telèfon.';

  @override
  String get voiceRecording => 'Gravació de veu';

  @override
  String get retryCaptures => 'Torna a carregar les captures';

  @override
  String get capturesCaughtUp => 'Tot al dia';

  @override
  String get capturesEmptyHelp =>
      'Les gravacions i els esborranys que deixis pendents es conservaran aquí.';

  @override
  String get captureResumeHelp =>
      'Conservat en aquest telèfon · Toca per continuar';

  @override
  String captureDraftSummary(int count, int ready) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count esborranys',
      one: '1 esborrany',
    );
    String _temp1 = intl.Intl.pluralLogic(
      ready,
      locale: localeName,
      other: '$ready a punt',
      one: '1 a punt',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String editCaptureItem(String title) {
    return 'Edita $title';
  }

  @override
  String removeCaptureItem(String title) {
    return 'Treu $title';
  }

  @override
  String captureTasksAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasques afegides',
      one: '1 tasca afegida',
    );
    return '$_temp0';
  }

  @override
  String captureKeptForReview(int count) {
    return '$count conservades per revisar';
  }

  @override
  String get captureConfirmDetails => 'Utilitza els detalls mostrats';

  @override
  String get captureNothingToReview => 'No queda res per revisar';

  @override
  String get captureRemovedDraftsHelp =>
      'Els esborranys eliminats no es convertiran en tasques.';

  @override
  String get captureFinish => 'Fet';

  @override
  String get captureYourWords => 'Les teves paraules';

  @override
  String get captureReviewRetainedHelp =>
      'Els esborranys pendents es conserven en aquest telèfon. Hi pots tornar des de Captures pendents.';

  @override
  String get captureCheckDetails => 'Revisa els detalls de sobre';

  @override
  String get captureUnderstanding => 'Entenent…';

  @override
  String captureThingsToAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coses per afegir',
      one: '1 cosa per afegir',
    );
    return '$_temp0';
  }

  @override
  String get captureAddToCalendar => 'Afegeix al calendari';

  @override
  String get captureAddTask => 'Afegeix la tasca';

  @override
  String captureAddTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Afegeix $count tasques',
      one: 'Afegeix 1 tasca',
    );
    return '$_temp0';
  }

  @override
  String get captureSayAgain => 'Torna-ho a dir';

  @override
  String get labelsExample => 'casa, encàrrecs, trucades';

  @override
  String get account => 'Compte';

  @override
  String completedTaskSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tasques completades. Toca una marca per tornar a obrir la tasca.',
      one: '1 tasca completada. Toca la marca per tornar-la a obrir.',
    );
    return '$_temp0';
  }

  @override
  String get taskTitleHint => 'p. ex. Visita al metge';

  @override
  String individualDateChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canvis de data individuals',
      one: '1 canvi de data individual',
    );
    return '$_temp0';
  }

  @override
  String movedOccurrenceDate(String date) {
    return 'Moguda al $date';
  }

  @override
  String reopenNamedTask(String title) {
    return 'Torna a obrir $title';
  }

  @override
  String completeNamedTask(String title) {
    return 'Completa $title';
  }

  @override
  String get viewOnlyTaskTitle => 'Tasca de només lectura';

  @override
  String get readOnlyList => 'Aquest projecte és de només lectura';

  @override
  String get listEditingAccessHelp =>
      'El propietari del projecte gestiona els permisos d’edició.';

  @override
  String get loadTaskError => 'No s’ha pogut carregar aquesta tasca';

  @override
  String deleteSeriesHelp(String title) {
    return 'Se suprimiran «$title» i totes les seves repeticions.';
  }

  @override
  String deleteItemHelp(String title) {
    return 'Se suprimirà «$title».';
  }

  @override
  String get viewOnlyTask =>
      'Tasca compartida de només lectura. El propietari del projecte gestiona els permisos d’edició.';

  @override
  String get stepUpdateError =>
      'No s’ha pogut actualitzar aquest pas. Torna-ho a provar.';

  @override
  String get checklistCompletionHelp =>
      'Completar tots els passos no completa la tasca. Utilitza Completa quan hagis acabat.';

  @override
  String get diagnosticsPrivacy =>
      'Comptadors i temps locals dels últims 1.000 esdeveniments. No inclouen títols de tasques, paraules, gravacions ni identificadors de compte. No es puja cap dada d’aquesta pantalla.';

  @override
  String get diagnosticsPercentiles =>
      'La mediana és l’observació central. El P95 és el temps dins del qual acaba el 95% de les observacions. Les peticions fallides es compten a part.';

  @override
  String get diagnosticsMeasurementHelp =>
      'Conservar una captura per a més endavant no és un error. Els recomptes poden incloure diverses visites al mateix esborrany; no són una taxa de conversió. El temps de correcció inclou els diàlegs d’edició oberts, també els cancel·lats. El temps de desament local exclou la sincronització amb el núvol. La transcripció d’àudio exclou el text escrit i el reconeixement local.';

  @override
  String diagnosticsObservations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observacions',
      one: '1 observació',
    );
    return '$_temp0';
  }

  @override
  String diagnosticsItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elements',
      one: '1 element',
    );
    return '$_temp0';
  }

  @override
  String diagnosticsTiming(String median, String p95, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observacions cronometrades',
      one: '1 observació cronometrada',
    );
    return 'Mediana $median s · P95 $p95 s · $_temp0';
  }

  @override
  String get diagnosticsClearError =>
      'No s’ha pogut esborrar el diagnòstic. Torna-ho a provar.';

  @override
  String get clearDiagnostics => 'Esborra el diagnòstic local';

  @override
  String diagnosticsEvent(String event) {
    String _temp0 = intl.Intl.selectLogic(event, {
      'opened': 'Captura oberta',
      'ready': 'Captura a punt',
      'started': 'Captures persistents noves',
      'typedStarted': 'Inici d’entrada de text',
      'permissionDenied': 'Permís de micròfon denegat',
      'nativeStarted': 'Inici de reconeixement local',
      'firstPartial': 'Primeres paraules locals',
      'nativeListening': 'Durada del reconeixement local',
      'recordingStopped': 'Durada de l’àudio desat',
      'transcription': 'Transcripció d’àudio en línia',
      'extraction': 'Extracció de tasques en línia',
      'processing': 'Petició i esborranys conservats',
      'notePrepared': 'Nota local preparada',
      'noteTranscribed': 'Nota gravada a punt',
      'failed': 'Peticions fallides',
      'retried': 'Peticions repetides',
      'edited': 'Canvis d’esborrany',
      'reviewOpened': 'Revisió oberta',
      'reviewTime': 'Temps de revisió',
      'correction': 'Temps del diàleg de correcció',
      'saved': 'De confirmació a desament local',
      'discarded': 'Captures descartades explícitament',
      'resumed': 'Captures represes',
      'leftCapturePending': 'Captura conservada per a més endavant',
      'leftReviewPending': 'Revisió conservada per a més endavant',
      'other': 'Altre esdeveniment de captura',
    });
    return '$_temp0';
  }

  @override
  String get taskflowPro => 'TaskFlow Pro';

  @override
  String get billingSettingsHelp => 'Subscripció, compres i facturació';

  @override
  String get billingIntro => 'La teva subscripció, en un sol lloc.';

  @override
  String get billingComplimentary =>
      'Accés Pro gratuït. Totes les funcions Pro estan incloses, sense pagaments ni renovacions.';

  @override
  String billingStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'active': 'Pro està actiu',
      'inactive': 'No hi ha cap subscripció Pro activa',
      'other': 'Estat de subscripció no disponible',
    });
    return '$_temp0';
  }

  @override
  String billingUntil(String kind, String date) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'renews': 'Es renova el $date',
      'other': 'Accés fins al $date',
    });
    return '$_temp0';
  }

  @override
  String get billingTestMode =>
      'Només compres de prova. No es farà cap cobrament real. Una subscripció de prova activa desbloqueja la captura per veu i amb IA en aquesta versió de desenvolupament.';

  @override
  String get billingGuestHelp =>
      'Inicia la sessió per vincular les compres al compte de TaskFlow i recuperar Pro als altres dispositius.';

  @override
  String get billingSignIn => 'Inicia la sessió a TaskFlow';

  @override
  String get billingWorking => 'S’està actualitzant la subscripció';

  @override
  String billingMonthlyPrice(String price) {
    return '$price / mes';
  }

  @override
  String get billingRenewalHelp =>
      'Es renova automàticament cada mes fins que es cancel·la. Revisa el preu final i les condicions de qualsevol prova abans de confirmar.';

  @override
  String get billingViewPlans => 'Mostra la subscripció';

  @override
  String get billingTestMonthly => 'Prova la compra mensual';

  @override
  String get billingRestore => 'Restaura les compres';

  @override
  String get billingManage => 'Gestiona la subscripció';

  @override
  String get billingOpenStore => 'Obre les subscripcions de la botiga';

  @override
  String get billingRefresh => 'Actualitza l’estat';

  @override
  String get billingRestoreHelp =>
      'Ja tens una subscripció? Utilitza el mateix compte de la botiga i restaura les compres. Cancel·lar la renovació manté Pro disponible fins que acaba el període pagat.';

  @override
  String get billingStoreOpenError =>
      'No s’ha pogut obrir la botiga. Torna-ho a provar o obre la configuració de subscripcions de la botiga.';

  @override
  String billingError(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'unsupportedPlatform':
          'Les subscripcions estan disponibles a l’aplicació d’Android i iOS.',
      'configuration':
          'Les subscripcions encara no estan disponibles. Torna-ho a provar més endavant.',
      'accountUnavailable':
          'Connecta’t al servidor de TaskFlow per vincular la subscripció i actualitza l’estat.',
      'network':
          'No s’ha pogut actualitzar la facturació. Comprova la connexió i actualitza.',
      'notAllowed':
          'Les compres estan restringides per a aquest compte de la botiga o dispositiu.',
      'otherAccount':
          'Aquesta compra pertany a un altre compte. Inicia la sessió amb el compte original per restaurar-la.',
      'store': 'La botiga no ha pogut completar la petició. Torna-ho a provar.',
      'other': 'No s’ha pogut actualitzar la subscripció. Torna-ho a provar.',
    });
    return '$_temp0';
  }

  @override
  String billingResult(String result) {
    String _temp0 = intl.Intl.selectLogic(result, {
      'active': 'TaskFlow Pro està actiu.',
      'restored': 'S’ha restaurat la subscripció Pro.',
      'noPurchases':
          'No s’ha trobat cap compra Pro activa per a aquest compte.',
      'awaitingEntitlement':
          'Compra rebuda. Pro encara no està actiu; actualitza o restaura les compres d’aquí a un moment.',
      'updated': 'Estat de subscripció actualitzat.',
      'pending':
          'El pagament està pendent. Pro s’activarà quan la botiga el confirmi.',
      'busy': 'Espera que acabi l’operació actual.',
      'accountChanged':
          'El compte ha canviat. Consulta la subscripció al compte que va fer la compra.',
      'other': 'No s’ha pogut completar la petició. Torna-ho a provar.',
    });
    return '$_temp0';
  }

  @override
  String get continueWithGoogle => 'Continua amb Google';

  @override
  String get linkGoogleAccount => 'Vincula el compte de Google';

  @override
  String get googleAccountLinked => 'Compte de Google vinculat';

  @override
  String get googleLinkHelp =>
      'Confirma la contrasenya de TaskFlow i tria el compte de Google amb el mateix correu. Les tasques i la subscripció es mantindran en aquest compte.';

  @override
  String get googleSignInSetupPending =>
      'L’accés amb Google encara no està disponible en aquesta versió. Pots fer servir el correu i la contrasenya.';

  @override
  String googleSignInError(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'google_not_configured':
          'L’accés amb Google encara no està disponible. Fes servir el correu i la contrasenya.',
      'google_link_required':
          'Aquest correu ja té un compte de TaskFlow. Accedeix-hi amb la contrasenya i tria Vincula el compte de Google.',
      'google_password_required':
          'Introdueix la contrasenya actual de TaskFlow per vincular Google.',
      'google_email_mismatch':
          'Tria el compte de Google amb el mateix correu que el compte de TaskFlow.',
      'google_already_linked':
          'Aquest compte de Google ja està vinculat. Accedeix al compte original de TaskFlow.',
      'google_account_changed':
          'El compte ha canviat durant l’accés. Torna-ho a provar.',
      'google_invalid_token':
          'Google no ha pogut verificar l’accés. Torna-ho a provar.',
      'other':
          'No s’ha pogut completar l’accés amb Google. Comprova la connexió i torna-ho a provar.',
    });
    return '$_temp0';
  }

  @override
  String get authWelcome => 'El teu dia, més clar.';

  @override
  String get authRegisterHelp =>
      'Totes les teves tasques i notes, amb tu allà on vagis.';

  @override
  String get authOr => 'o';

  @override
  String get authRestoring => 'Obrint el teu espai…';

  @override
  String get authHaveRecoveryCode => 'Ja tinc un codi';

  @override
  String get authEnterRecoveryCode =>
      'Introdueix el codi del correu de recuperació.';

  @override
  String get useTestAccount => 'Entrar amb un compte de prova';

  @override
  String get developmentOnly => 'Només en desenvolupament';

  @override
  String get projectsAll => 'Tots els projectes';

  @override
  String get projectsPersonal => 'Projectes personals';

  @override
  String get projectsShared => 'Projectes compartits';

  @override
  String get projectsFind => 'Cerca un projecte';

  @override
  String get projectsManage => 'Gestiona els projectes';

  @override
  String get forMe => 'Per a mi';

  @override
  String get forTeam => 'Equip';

  @override
  String get responsibility => 'Responsable';

  @override
  String get assignedToMe => 'Jo';

  @override
  String get assignedToGroup => 'Tot el grup';

  @override
  String get assignmentNeeded => 'Cal un responsable';

  @override
  String get assignmentChoose => 'Qui és responsable?';

  @override
  String get assignmentGroupHelp =>
      'Una tasca compartida. Un membre la completa per a tothom.';

  @override
  String assignmentHeard(Object names) {
    return 'Has esmentat: $names';
  }

  @override
  String get audiencePersonal => 'Només tu ho pots veure.';

  @override
  String audienceShared(Object name) {
    return 'Visible per a tothom a $name';
  }

  @override
  String shareTaskConfirm(String name) {
    return 'Vols compartir-la amb $name? Tothom la veurà i no la podràs tornar a fer privada.';
  }

  @override
  String get shareTask => 'Comparteix';

  @override
  String get sharedTaskStays =>
      'Les tasques compartides es queden al seu projecte.';

  @override
  String get assignmentIsRight => 'És correcte?';

  @override
  String get yes => 'Sí';

  @override
  String get pinProject => 'Fixa el projecte';

  @override
  String get unpinProject => 'Desfixa el projecte';

  @override
  String get groups => 'Grups';

  @override
  String get newGroup => 'Grup nou';

  @override
  String get groupName => 'Nom del grup';

  @override
  String get groupHelp =>
      'Convida les persones una vegada i col·laboreu en diversos projectes.';

  @override
  String get groupMembers => 'Membres';

  @override
  String get groupAdmin => 'Administrador';

  @override
  String get groupProjects => 'Projectes del grup';

  @override
  String get groupInviteHelp =>
      'Veuran tots els projectes d’aquest grup, incloses les tasques, notes i fitxers. Els enviarem un correu per revisar la invitació i unir-s’hi.';

  @override
  String get groupJoin => 'Uneix-me al grup';

  @override
  String get groupLeave => 'Surt del grup';

  @override
  String get groupLeaveHelp =>
      'Perdràs l’accés als projectes i fitxers del grup. Les teves tasques es quedaran al grup per reassignar-les.';

  @override
  String get groupTransfer => 'Transfereix la propietat';

  @override
  String get groupTransferHelp =>
      'El nou propietari controlarà aquest grup i els seus projectes. Continuaràs com a administrador.';

  @override
  String get groupArchive => 'Arxiva el grup';

  @override
  String get groupRestore => 'Restaura el grup';

  @override
  String get groupDeleteHelp =>
      'Només pots suprimir un grup buit. Arxiva’l per conservar-ne els projectes i el contingut.';

  @override
  String get groupActionError =>
      'No s’ha pogut desar el canvi. Comprova la connexió i actualitza; els permisos poden haver canviat.';

  @override
  String get groupVoiceName => 'El teu nom per a la veu';

  @override
  String get groupVoiceHelp =>
      'Un nom opcional que els altres poden fer servir per assignar-te tasques per veu.';

  @override
  String get groupOnline => 'Connecta’t per gestionar membres i invitacions.';

  @override
  String get projectDestination => 'On va aquest projecte?';

  @override
  String get projectNotifications => 'Novetats del projecte';

  @override
  String get updatesAll => 'Tots els canvis';

  @override
  String get updatesAssigned => 'Les meves assignacions';

  @override
  String get updatesMuted => 'Silenciades';

  @override
  String get activity => 'Activitat';

  @override
  String get activityEmpty => 'Estàs al dia.';

  @override
  String get activityHelp =>
      'Aquí apareixen les assignacions i novetats dels teus projectes compartits.';

  @override
  String get activityMarkRead => 'Marca-ho tot com a llegit';

  @override
  String get activityCreated => 'Ha creat una tasca';

  @override
  String get activityUpdated => 'Ha actualitzat una tasca';

  @override
  String get activityAssigned => 'Ha canviat el responsable';

  @override
  String get activityCompleted => 'Ha completat una tasca';

  @override
  String get activityReopened => 'Ha reobert una tasca';

  @override
  String get activityDeleted => 'Ha suprimit una tasca';

  @override
  String get activitySystem => 'TaskFlow';

  @override
  String get voiceProRequired =>
      'La captura per veu està inclosa a TaskFlow Pro.';

  @override
  String get voiceProAction => 'Descobreix Pro';

  @override
  String get voiceAccessUnavailable =>
      'No hem pogut verificar l’accés per veu. La captura està desada; torna a connectar-te i prova-ho de nou.';

  @override
  String get projectsNoneFound => 'No s’han trobat projectes';

  @override
  String get groupRename => 'Canvia el nom del grup';

  @override
  String get groupRemoveHelp =>
      'Si elimines aquest membre, perdrà accés a tots els projectes del grup. Les seves tasques es conservaran i caldrà reassignar-les.';

  @override
  String get projectsPinned => 'Projectes fixats';

  @override
  String get invitationEmailSent =>
      'Invitació enviada per correu. També pots compartir el codi de sota.';

  @override
  String get invitationEmailPending =>
      'La invitació està preparada. El correu està pendent i es tornarà a intentar automàticament. Pots compartir aquest codi ara.';

  @override
  String get invitationReview => 'Revisa la invitació';

  @override
  String get invitationReviewHelp =>
      'En unir-te tindràs accés als projectes compartits, tasques, notes i fitxers que s’indiquen a continuació.';

  @override
  String get invitationUnavailable =>
      'Aquesta invitació no està disponible per a aquest compte. Comprova que hagis iniciat sessió amb el correu que l’ha rebuda o demana una invitació nova.';

  @override
  String get stagingInviteOnly =>
      'Aquesta versió de prova privada és per a persones convidades. Demana al responsable de TaskFlow una invitació a aquest correu.';
}
