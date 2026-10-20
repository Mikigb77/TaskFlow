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
  String get scheduleHourRange24 => 'Hora del 0 al 23';

  @override
  String get scheduleHourRange12 => 'Hora de l’1 al 12';

  @override
  String get scheduleMinuteRange => 'Minuts del 0 al 59';

  @override
  String get reviewOptions => 'Més opcions';

  @override
  String get reviewOriginal => 'Mostra què he dit';

  @override
  String get reviewOriginalText => 'Text original';

  @override
  String get reviewRemove => 'Treu';

  @override
  String get reviewRemoved => 'Treta';

  @override
  String get reviewUndoSaved => 'Tornen a ser aquí, sense desar.';

  @override
  String get reviewUndoChanged =>
      'Aquesta tasca ha canviat. S’han conservat les tasques desades.';

  @override
  String get reviewRepair => 'Corregeix el text';

  @override
  String get reviewRepairHelp =>
      'Aquest text pot tenir accents malmesos. Revisa la correcció abans de desar.';

  @override
  String get reviewConfirmDetail => 'Així està bé';

  @override
  String get reviewNoTime => 'Sense hora';

  @override
  String get captureWhatTime => 'A quina hora?';

  @override
  String get reviewEditDetail => 'Canvia aquesta dada';

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
          'Aquesta persona ja hi té accés. Gestiona’n el rol a Membres.',
      'memberLimit':
          'Aquest projecte admet fins a 20 membres i 20 invitacions pendents. Primer elimina algú o anul·la una invitació.',
      'accepted':
          'Aquesta invitació ja s’ha acceptat. Gestiona l’accés de la persona a Membres.',
      'owner':
          'El propietari no pot sortir. Pots suprimir el projecte si ja no el necessites.',
      'expired':
          'Aquesta invitació ja no està disponible. Demana’n una de nova al propietari.',
      'code': 'Demana al propietari del projecte el codi d’invitació actual.',
      'refresh':
          'Aquest projecte ha canviat. Actualitza’l abans de suprimir-lo.',
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
          'L’accés a un projecte compartit ha canviat. Actualitza per acabar de sincronitzar els canvis permesos.',
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
      'emailUsed': 'Aquest correu ja té un compte.',
      'email': 'Introdueix una adreça de correu vàlida.',
      'credentials': 'No trobem aquest compte o la contrasenya no és correcta.',
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
      'fileLimit': 'Tria un fitxer no buit de fins a 6 MB.',
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
  String get languageAutomatic => 'Com el telèfon';

  @override
  String languageFollowing(String language) {
    return 'Com el telèfon · $language';
  }

  @override
  String get regionalFormats => 'Hora i regió';

  @override
  String get sharedCaptureRetained =>
      'El que has compartit s’ha conservat. Torna a obrir TaskFlow per tornar-ho a provar.';

  @override
  String get note => 'Nota';

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
  String get addNote => 'Afegeix una nota';

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
  String get viewOnlyNote =>
      'Nota de només lectura. Si vols fer canvis, demana-ho al propietari del projecte.';

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
  String get duration => 'Durada';

  @override
  String get durationUnset => 'Sense durada';

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
  String get deadlineTime => 'Hora límit';

  @override
  String get deadlineEndDay => 'Abans que acabi el dia';

  @override
  String get removeDeadline => 'Treu el termini';

  @override
  String get deadlineRecurringHelp => 'Cada repetició té el seu propi termini.';

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
  String get reminderAnchor => 'Recorda-m’ho abans de';

  @override
  String get dayTimeline => 'Horari del dia';

  @override
  String get timelineLimit =>
      'Es mostren els primers 200 elements amb hora. Utilitza l’agenda per veure totes les tasques.';

  @override
  String get timelineUnblocked => 'Sense hora';

  @override
  String get timelineNoBlocks => 'No hi ha res amb hora aquest dia.';

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
  String get noScheduledTasks => 'No hi ha tasques per a aquest dia.';

  @override
  String get calendar => 'Calendari';

  @override
  String get tasks => 'Tasques';

  @override
  String get settings => 'Configuració';

  @override
  String get inbox => 'Sense data';

  @override
  String inboxCount(int count) {
    return 'Sense data · $count';
  }

  @override
  String get today => 'Avui';

  @override
  String get tomorrow => 'Demà';

  @override
  String get yesterday => 'Ahir';

  @override
  String get all => 'Totes';

  @override
  String get upcoming => 'Properes';

  @override
  String get noDate => 'Sense data';

  @override
  String get anyTime => 'Sense hora';

  @override
  String get addTime => 'Afegeix una hora';

  @override
  String get removeDate => 'Treu la data';

  @override
  String get editTask => 'Edita la tasca';

  @override
  String get taskScreenTitle => 'Tasca';

  @override
  String get addTask => 'Afegeix una tasca';

  @override
  String get typeTasks => 'Escriu tasques';

  @override
  String get unfinishedCaptures => 'Sense desar';

  @override
  String get captureDiagnostics => 'Diagnòstic de captures';

  @override
  String get lists => 'Projectes';

  @override
  String get labels => 'Etiquetes';

  @override
  String get noList => 'Sense projecte';

  @override
  String get priority => 'Prioritat';

  @override
  String get low => 'Baixa';

  @override
  String get medium => 'Mitjana';

  @override
  String get high => 'Alta';

  @override
  String get date => 'Data';

  @override
  String get time => 'Hora';

  @override
  String get repeat => 'Repetició';

  @override
  String get repeatNeedsDate => 'Afegeix una data per repetir';

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
  String get checklist => 'Llista de passos';

  @override
  String get complete => 'Completa';

  @override
  String get reopen => 'Torna a obrir';

  @override
  String get reschedule => 'Canvia la data';

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
  String get light => 'Clar';

  @override
  String get dark => 'Fosc';

  @override
  String get reminders => 'Recordatoris';

  @override
  String remindersOnLead(String lead) {
    return 'Activats · $lead';
  }

  @override
  String get remindersOff => 'Desactivats';

  @override
  String get remindersBlocked => 'Bloquejats pel telèfon';

  @override
  String get otherSettings => 'Altres opcions';

  @override
  String appVersion(String version) {
    return 'TaskFlow $version';
  }

  @override
  String get completedTasks => 'Tasques completades';

  @override
  String get exportImport => 'Exporta i importa';

  @override
  String get language => 'Idioma';

  @override
  String get deviceDefault => 'Com el telèfon';

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
  String get timeZone => 'Fus horari';

  @override
  String get timezoneHelp =>
      'Les tasques noves fan servir aquest fus horari per entendre les dates.';

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
    return 'El fus horari del dispositiu no està disponible. Les tasques noves utilitzaran $zone.';
  }

  @override
  String get week => 'Setmana';

  @override
  String get month => 'Mes';

  @override
  String get day => 'Dia';

  @override
  String get previousWeek => 'Setmana anterior';

  @override
  String get nextWeek => 'Setmana següent';

  @override
  String get previousMonth => 'Mes anterior';

  @override
  String get nextMonth => 'Mes següent';

  @override
  String dayTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasques',
      one: '1 tasca',
    );
    return '$_temp0';
  }

  @override
  String get previousDay => 'Dia anterior';

  @override
  String get nextDay => 'Dia següent';

  @override
  String get licenses => 'Llicències de codi obert';

  @override
  String get privacyPolicy => 'Política de privacitat';

  @override
  String get termsAndConditions => 'Termes i condicions';

  @override
  String get todayAgenda => 'L’agenda d’avui';

  @override
  String get loadTasksError => 'No s’han pogut carregar les tasques';

  @override
  String get refreshCalendar => 'Prova d’actualitzar el calendari.';

  @override
  String get tryAgain => 'Torna-ho a provar';

  @override
  String get rememberPrompt => 'Què t’agradaria recordar?';

  @override
  String get calendarEmpty => 'Res previst per a aquest dia.';

  @override
  String get calendarTrySaying =>
      'Prova-ho: toca Afegeix una tasca i digues «Demà, trucar al dentista i comprar pa».';

  @override
  String get calendarTryTyping =>
      'Prova-ho: toca Afegeix una tasca i escriu «Demà, trucar al dentista».';

  @override
  String get calendarTryForm =>
      'Prova-ho: toca Tasca nova, escriu «Trucar al dentista» i toca Demà.';

  @override
  String get planTask => 'Planifica una tasca';

  @override
  String get homeCapture => 'Botó de dictar a la pantalla d’inici';

  @override
  String get homeCaptureInstructions =>
      'A Android, mantén premuda la icona de TaskFlow per veure’n les dreceres o afegeix el giny Dicta una tasca des de la pantalla d’inici. També pots compartir text amb TaskFlow des d’una altra aplicació.';

  @override
  String get widgetPickerHelp =>
      'Afegeix el giny de TaskFlow des del selector de ginys de la pantalla d’inici.';

  @override
  String get appearanceError =>
      'No s’ha pogut desar la preferència d’aparença.';

  @override
  String get list => 'Projecte';

  @override
  String get archivedList => 'Projecte arxivat';

  @override
  String get yourTasks => 'Les teves tasques';

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
  String personNothingOpen(String name) {
    return '$name no té tasques pendents aquí';
  }

  @override
  String get personNothingOpenHelp => 'Toca Totes per veure totes les tasques.';

  @override
  String get listEmpty =>
      'Afegeix una tasca a aquest projecte. Tu tries la data i el recordatori.';

  @override
  String get readOnlyListEmpty => 'Aquest projecte encara no té tasques.';

  @override
  String get tasksEmpty =>
      'Toca Afegeix una tasca per afegir-ne una. La data és opcional.';

  @override
  String get inboxEmpty =>
      'Les tasques sense data esperen aquí fins que en triïs una.\nComença amb Afegeix una tasca.';

  @override
  String get tasksEmptyForm =>
      'Toca Tasca nova per afegir-ne una. La data és opcional.';

  @override
  String get inboxEmptyForm =>
      'Les tasques sense data esperen aquí fins que en triïs una.\nComença amb Tasca nova.';

  @override
  String get savedOnDevice => 'Les tasques desades continuen al dispositiu.';

  @override
  String get checkCaptures => 'Mostra el que falta per desar';

  @override
  String get seriesEdits => 'Els canvis s’apliquen a tota la tasca periòdica.';

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
  String get keepTask => 'Conserva la tasca';

  @override
  String get deleteTaskError =>
      'No s’ha pogut suprimir aquesta tasca. Torna-ho a provar.';

  @override
  String get taskDeleted => 'Tasca suprimida';

  @override
  String get noteDeleted => 'Nota suprimida';

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
  String get moveError =>
      'No s’ha pogut moure aquesta tasca. Torna-ho a provar.';

  @override
  String get occurrence => 'Repetició';

  @override
  String get starts => 'Comença';

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
  String get onDeviceTranscript => 'Al telèfon, mentre parles';

  @override
  String get onlineAudio => 'En línia, en acabar';

  @override
  String get speechMethod => 'Com es passa la veu a text';

  @override
  String get speechLanguage => 'Idioma de la veu';

  @override
  String get voiceSettings => 'Veu';

  @override
  String get sameAsApp => 'Com l’aplicació';

  @override
  String get onDeviceUnavailable =>
      'Aquest telèfon no pot amb aquest idioma tot sol, així que TaskFlow ho fa en línia.';

  @override
  String get setUpSpeech => 'Configura el reconeixement de veu local';

  @override
  String get checkAgain => 'Torna a comprovar-ho';

  @override
  String get examplePlan =>
      'Metge divendres a les 17 h. Portar els resultats. També comprar cafè.';

  @override
  String get exampleTask => 'Metge divendres a les 17:00';

  @override
  String get discard => 'Descarta';

  @override
  String get keep => 'Conserva';

  @override
  String get capturePrivacy =>
      'La transcripció en directe utilitza el reconeixement local quan està disponible; en aquest mode no es conserva l’àudio. L’extracció de tasques amb IA necessita internet i envia les teves paraules a Google. L’àudio desat es transcriu en línia. El que encara no has desat es queda en aquest telèfon fins que ho desis o ho descartis.';

  @override
  String get capturePrivacyLine =>
      'Les paraules van per internet. Més a Configuració.';

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
    String _temp0 = intl.Intl.pluralLogic(
      done,
      locale: localeName,
      other: '$remaining per fer · $done completades',
      one: '$remaining per fer · 1 completada',
      zero: '$remaining per fer',
    );
    return '$_temp0';
  }

  @override
  String overdueDate(String date) {
    return '$date · Endarrerida';
  }

  @override
  String assigneeLabel(String name) {
    return 'Responsable: $name';
  }

  @override
  String projectLabel(String name) {
    return 'Projecte: $name';
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
    return 'Sense desar · $count';
  }

  @override
  String listeningSeconds(String time) {
    return 'S’està escoltant · $time';
  }

  @override
  String repeatEvery(int interval, String frequency) {
    String _temp0 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Cada $interval dies',
      one: 'Cada dia',
    );
    String _temp1 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Cada $interval setmanes',
      one: 'Cada setmana',
    );
    String _temp2 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Cada $interval mesos',
      one: 'Cada mes',
    );
    String _temp3 = intl.Intl.pluralLogic(
      interval,
      locale: localeName,
      other: 'Cada $interval anys',
      one: 'Cada any',
    );
    String _temp4 = intl.Intl.selectLogic(frequency, {
      'daily': '$_temp0',
      'weekly': '$_temp1',
      'monthly': '$_temp2',
      'other': '$_temp3',
    });
    return '$_temp4';
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
  String get editStep => 'Edita el pas';

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
  String get addStep => 'Afegeix un pas';

  @override
  String get stepLimit =>
      'Una tasca pot tenir fins a 50 passos. Treu-ne un per afegir aquest.';

  @override
  String get listUnavailable => 'Projecte no disponible';

  @override
  String get archived => 'Arxivat';

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
  String get movedInbox => 'S’ha tret la data';

  @override
  String get scheduleChangedAgain =>
      'La data ha tornat a canviar. Obre la tasca per revisar-la.';

  @override
  String get scheduleError =>
      'No s’ha pogut canviar la data. Torna-ho a provar.';

  @override
  String get rescheduleRepeating => 'Canvia la data de la tasca periòdica';

  @override
  String get rescheduleTask => 'Canvia la data de la tasca';

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
  String get completedButton => 'Completades';

  @override
  String get completedLoadError =>
      'No s’han pogut carregar les tasques completades';

  @override
  String get tryLater => 'Torna-ho a provar d’aquí a un moment.';

  @override
  String get changeSeriesQuestion => 'Vols canviar com es repeteix?';

  @override
  String get changeSeriesHelp =>
      'Les dates que vas moure o ometre seguiran la repetició nova. Les dates completades es queden a l’historial.';

  @override
  String get keepEditing => 'Continua editant';

  @override
  String get resetSave => 'Restableix i desa';

  @override
  String get taskSavedInbox => 'Afegida sense data';

  @override
  String taskAddedOn(String date) {
    return 'Afegida al $date';
  }

  @override
  String taskAddedDue(String date) {
    return 'Afegida · venç el $date';
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
  String get titleRequiredField => 'Introdueix un títol per a la tasca';

  @override
  String get fromYourWords => 'Segons el que has escrit';

  @override
  String get keepAsTyped => 'Deixa-ho com està';

  @override
  String get optionalTime => 'Hora (opcional)';

  @override
  String get resetDateHelp => 'Restableix una data i desa els canvis.';

  @override
  String get skipped => 'Omesa';

  @override
  String get labelLimit =>
      'Utilitza fins a 10 etiquetes de fins a 32 caràcters cadascuna.';

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
  String checklistCount(int done, int total) {
    return 'Passos · $done/$total';
  }

  @override
  String checklistSemantics(int done, int total) {
    return 'Llista de passos, $done de $total completats';
  }

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
  String reminderForPerson(String name, String value) {
    return 'Recordatori per a $name: $value';
  }

  @override
  String reminderForPersonOnly(String name) {
    return 'Recordatori per a $name';
  }

  @override
  String get noReminderProjectMuted => 'Sense recordatori: projecte silenciat';

  @override
  String get noReminderProjectArchived => 'Sense recordatori: projecte arxivat';

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
  String get fileRetry => 'Torna a pujar';

  @override
  String get fileRemove => 'Treu el fitxer adjunt';

  @override
  String removeFileNamed(String file) {
    return 'Treu $file';
  }

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
  String get accountSaved => 'Desat al teu compte';

  @override
  String get syncNow => 'Sincronitza ara';

  @override
  String get accountSyncing => 'S’està sincronitzant';

  @override
  String get importLocalItems => 'Importa tasques i notes locals';

  @override
  String get accountImporting => 'S’estan important les tasques i les notes';

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
  String get accountSigningOut => 'S’està tancant la sessió';

  @override
  String get signOutQuestion =>
      'Vols tancar la sessió? Deixaràs de rebre recordatoris en aquest telèfon fins que tornis a entrar.';

  @override
  String get recoveryHeading => 'Recupera la contrasenya';

  @override
  String get registerHeading => 'Crea el teu compte';

  @override
  String get signInHeading => 'Inicia la sessió';

  @override
  String get authPitch =>
      'Apunta el que has de fer i TaskFlow ho posa al teu calendari.';

  @override
  String get signInAgainReason =>
      'S’ha tancat la sessió. Torna a entrar i continuaràs on ho havies deixat.';

  @override
  String get recoveryHelp =>
      'Demana un correu de recuperació i utilitza el codi per establir una contrasenya nova.';

  @override
  String get email => 'Correu';

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
  String get passwordHelp => 'Com a mínim 12 caràcters, no només números';

  @override
  String get passwordTooShort => 'Utilitza com a mínim 12 caràcters';

  @override
  String get enterPassword => 'Introdueix la contrasenya';

  @override
  String get showPassword => 'Mostra la contrasenya';

  @override
  String get hidePassword => 'Amaga la contrasenya';

  @override
  String get createAccount => 'Crea el compte';

  @override
  String get signIn => 'Inicia la sessió';

  @override
  String get alreadyHaveAccount => 'Ja tens un compte? Inicia la sessió';

  @override
  String get createAnAccount => 'Crea un compte';

  @override
  String get createAccountWithEmail => 'Crea un compte amb aquest correu';

  @override
  String get signInWithEmail => 'Inicia la sessió amb aquest correu';

  @override
  String get backToSignIn => 'Torna a l’inici de sessió';

  @override
  String get sendRecoveryCode => 'Envia el codi';

  @override
  String get saveNewPassword => 'Desa la contrasenya nova';

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
  String recoveryEmailRequested(String email) {
    return 'Si $email té compte, t’arribarà un correu amb un codi. Escriu-lo aquí.';
  }

  @override
  String get passwordResetComplete =>
      'Contrasenya actualitzada. Inicia la sessió amb la contrasenya nova.';

  @override
  String get verifyEmailHeading => 'Confirma el teu correu';

  @override
  String verifyEmailHelp(String email) {
    return 'T’hem enviat un codi de 6 xifres a $email. Escriu-lo aquí.';
  }

  @override
  String get verifyEmailCode => 'Codi';

  @override
  String get verifyEmailCodeLength => 'El codi té 6 xifres';

  @override
  String get verifyEmailConfirm => 'Confirma';

  @override
  String get verifyEmailConfirming => 'S’està confirmant';

  @override
  String get verifyEmailResend => 'Torna a enviar el codi';

  @override
  String verifyEmailResendIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Torna a enviar el codi d’aquí a $seconds segons',
      one: 'Torna a enviar el codi d’aquí a 1 segon',
    );
    return '$_temp0';
  }

  @override
  String verifyEmailResendInMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Torna a enviar el codi d’aquí a $minutes minuts',
      one: 'Torna a enviar el codi d’aquí a 1 minut',
    );
    return '$_temp0';
  }

  @override
  String verifyEmailResendLimited(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other:
          'Has demanat molts codis. Espera $minutes minuts per demanar-ne un altre.',
      one: 'Has demanat molts codis. Espera un minut per demanar-ne un altre.',
    );
    return '$_temp0';
  }

  @override
  String get verifyEmailResent =>
      'T’hem enviat un codi nou. Si no el veus, mira a Correu brossa o a Promocions.';

  @override
  String get verifyEmailCodeInvalid =>
      'Aquest codi no és correcte. Mira l’últim correu que t’hem enviat.';

  @override
  String get verifyEmailCodeSpentNew =>
      'Aquest codi ja no serveix. T’hem enviat un codi nou.';

  @override
  String get verifyEmailCodeSpentWait =>
      'Aquest codi ja no serveix. Toca «Torna a enviar el codi» quan acabi el compte enrere.';

  @override
  String get verifyEmailOtherAddress => 'Utilitza un altre correu';

  @override
  String get verifyEmailReplaced =>
      'Algú ha tornat a crear un compte amb aquest correu. Torna a crear-lo per continuar.';

  @override
  String get verifyEmailWrongPassword =>
      'Aquesta contrasenya no és la d’aquest compte. No la recordes? Toca «Utilitza un altre correu» i torna a crear el compte.';

  @override
  String get newList => 'Projecte nou';

  @override
  String get editList => 'Edita el projecte';

  @override
  String get listName => 'Nom';

  @override
  String get listNameHint => 'Casa, Feina, Compres…';

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
  String projectArchivedNoReminders(String name) {
    return '«$name» arxivat: ja no surt al calendari ni t’avisarà.';
  }

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
  String get listsEmptyTitle => 'Un espai per a cada part de la vida';

  @override
  String get listsEmptyHelp =>
      'Comença amb Casa, Feina o Compres. Pots moure les tasques quan vulguis.';

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
      'Modificat en un altre dispositiu · tria els detalls';

  @override
  String get archivedListHelp =>
      'Arxivat · les tasques i notes continuen disponibles';

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
  String get shareProject => 'Comparteix';

  @override
  String projectMembersCount(int count) {
    return 'Membres · $count';
  }

  @override
  String shareProjectTitle(String project) {
    return 'Comparteix $project';
  }

  @override
  String get theirEmail => 'El seu correu';

  @override
  String shareProjectHelp(String project) {
    return 'Veurà tot el que hi ha a $project.';
  }

  @override
  String get sendInvitation => 'Envia la invitació';

  @override
  String get invitationSent => 'Invitació enviada';

  @override
  String get invitationCodeFallback =>
      'Si no li arriba el correu, envia-li aquest codi:';

  @override
  String get connectToShare => 'Connecta’t a internet per compartir.';

  @override
  String get sendInvitationAgain => 'Torna a enviar';

  @override
  String get cancelInvitation => 'Anul·la la invitació';

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
  String get people => 'Membres';

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
  String deleteListPrivateHelp(String name) {
    return 'Vols suprimir «$name» amb totes les tasques, notes i fitxers? No es pot desfer.';
  }

  @override
  String get deleteListForEveryone => 'Suprimeix el projecte per a tothom';

  @override
  String get leaveList => 'Surt del projecte';

  @override
  String get leaveListHelp =>
      'Les tasques, notes i fitxers compartits, i els canvis pendents d’enviar, se suprimiran d’aquest telèfon. Els altres membres conservaran el projecte.';

  @override
  String youLeft(String name) {
    return 'Has sortit de $name';
  }

  @override
  String get projectDeleted => 'Projecte suprimit';

  @override
  String get groupDeleted => 'Grup suprimit';

  @override
  String get invitationCodeRequired => 'Enganxa el codi d’invitació complet.';

  @override
  String get invitationCodeWrong =>
      'Demana el codi actual a qui t’ha convidat.';

  @override
  String get invitationResponseError =>
      'No s’ha pogut respondre. Torna-ho a provar quan tinguis connexió.';

  @override
  String get retryInvitations => 'Torna a carregar les invitacions';

  @override
  String get acceptInvitation => 'Accepta la invitació';

  @override
  String get decline => 'Rebutja';

  @override
  String invitedTo(String name) {
    return 'T’han convidat a $name · Mostra';
  }

  @override
  String invitedByTo(String sender, String name) {
    return '$sender et convida a «$name» · Mostra';
  }

  @override
  String invitationsMore(int count) {
    return '+$count';
  }

  @override
  String joinInvitationTitle(String name) {
    return 'Uneix-te a $name';
  }

  @override
  String get joinInvitationHelp =>
      'Obre el correu d’invitació i toca’n l’enllaç. O enganxa-hi el codi que hi apareix.';

  @override
  String get joinInvitation => 'Uneix-me';

  @override
  String declineInvitationConfirm(String name) {
    return 'Vols rebutjar la invitació a $name? Per unir-t’hi més endavant en necessitaries una altra.';
  }

  @override
  String joinedInvitation(String name) {
    return 'T’has unit a $name';
  }

  @override
  String get invitationNotNow => 'Ara no';

  @override
  String signedInAs(String email) {
    return 'Sessió iniciada com a $email';
  }

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
      'Els fitxers nous es pugen al compte després de desar, fins a 6 MB cadascun. Els fitxers locals anteriors es queden al dispositiu fins que triïs Puja als detalls de la tasca.';

  @override
  String get fileLocalHelp =>
      'Els fitxers es queden en aquest dispositiu fins que iniciïs la sessió i triïs Puja als detalls de la tasca. Fins a 6 MB per fitxer.';

  @override
  String get fileLimit =>
      'Tria un fitxer no buit de fins a 6 MB. Pots adjuntar fins a 20 fitxers per tasca.';

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
  String get nameAskTitle => 'Com et dius?';

  @override
  String get nameAskBody =>
      'Així et veuran les persones amb qui comparteixes projectes.';

  @override
  String get nameAskField => 'Nom';

  @override
  String get nameAskNotNow => 'Ara no';

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
      'Els avisos propers s’actualitzen quan obres l’aplicació i, quan Android ho permet, cada hora.';

  @override
  String get backgroundAlertRefreshHelp =>
      'Els avisos propers s’actualitzen quan obres l’aplicació i quan el telèfon ho permet.';

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
  String get exportImportIntro =>
      'Desa una còpia de les tasques en un fitxer o porta tasques de Todoist.';

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
      other: '$count avisos posteriors encara no estan activats.',
      one: '1 avís posterior encara no està activat.',
    );
    return '$_temp0 La pròxima actualització activarà els més propers.';
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
      'Les importacions creen còpies personals noves. No s’hi inclouen l’accés al compte, els fitxers, les preferències de notificació ni el que encara no has desat.';

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
      'Cal revisar la planificació original; aquesta tasca quedarà sense data.';

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
  String notificationAt(String day, String date, String time, int hour) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'today': 'Avui a les $time',
      'tomorrow': 'Demà a les $time',
      'other': '$date a les $time',
    });
    String _temp1 = intl.Intl.selectLogic(day, {
      'today': 'Avui a la $time',
      'tomorrow': 'Demà a la $time',
      'other': '$date a la $time',
    });
    String _temp2 = intl.Intl.pluralLogic(
      hour,
      locale: localeName,
      other: '$_temp0',
      one: '$_temp1',
    );
    return '$_temp2';
  }

  @override
  String notificationDeadlineAt(
    String day,
    String date,
    String time,
    int hour,
  ) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'today': 'Termini: avui a les $time',
      'tomorrow': 'Termini: demà a les $time',
      'other': 'Termini: $date a les $time',
    });
    String _temp1 = intl.Intl.selectLogic(day, {
      'today': 'Termini: avui a la $time',
      'tomorrow': 'Termini: demà a la $time',
      'other': 'Termini: $date a la $time',
    });
    String _temp2 = intl.Intl.pluralLogic(
      hour,
      locale: localeName,
      other: '$_temp0',
      one: '$_temp1',
    );
    return '$_temp2';
  }

  @override
  String get notificationDeadlineToday => 'Termini: avui';

  @override
  String notificationInMinutes(String when, int minutes) {
    return '$when · d’aquí a $minutes min';
  }

  @override
  String notificationInHours(String when, int hours) {
    return '$when · d’aquí a $hours h';
  }

  @override
  String notificationCompleted(String title) {
    return 'Completada: $title';
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
  String get captureGone => 'Les teves paraules ja no estan disponibles.';

  @override
  String get captureNoteLength =>
      'Una nota ha de tenir entre 1 i 8.000 caràcters.';

  @override
  String get captureNoTasks =>
      'No he trobat cap tasca. Digues què i quan, per exemple: «Demà, trucar al dentista».';

  @override
  String get captureOffline =>
      'Sense connexió. Les teves paraules estan desades; torna-ho a provar quan tinguis internet.';

  @override
  String get captureUnavailable =>
      'No he pogut contactar amb l’assistent; les teves paraules es conserven.';

  @override
  String get captureTooFast =>
      'Has dictat moltes vegades seguides. Espera un minut i toca Torna-ho a provar.';

  @override
  String get captureAllowance =>
      'Has arribat al límit de dictats d’avui. Toca Desa-ho com a tasca o torna-ho a provar demà.';

  @override
  String get captureAllowanceRecording =>
      'Has arribat al límit de dictats d’avui. La gravació es conserva; torna-ho a provar demà.';

  @override
  String get captureSignIn =>
      'Torna a iniciar la sessió per convertir les teves paraules en tasques.';

  @override
  String get captureForbidden =>
      'Aquest compte no pot convertir les teves paraules en tasques. Revisa els permisos i torna-ho a provar.';

  @override
  String get captureTooLarge =>
      'Aquesta gravació és massa llarga. Descarta-la i dicta alguna cosa més curta.';

  @override
  String get captureTypedFirst =>
      'Desa o descarta el que has escrit abans de començar una gravació.';

  @override
  String get captureMicrophone =>
      'Sense micròfon no et puc escoltar. Toca Comença a parlar per permetre-ho, o Escriu.';

  @override
  String get captureMicrophoneBlocked =>
      'Per tornar a dictar, obre Configuració i toca Permisos › Micròfon › Permet.';

  @override
  String get captureOpenSettings => 'Obre Configuració';

  @override
  String get captureMicrophoneWhy =>
      'Permet el micròfon per dictar les tasques. Només escolta mentre dictes.';

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
  String get captureNothingHeardYet =>
      'Encara no he sentit res. Parla quan vulguis o toca Escriu.';

  @override
  String get captureListeningOnline =>
      'T’escolto. Veuràs les paraules quan toquis Fet.';

  @override
  String captureTimeLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Queden $seconds segons',
      one: 'Queda 1 segon',
    );
    return '$_temp0';
  }

  @override
  String get captureKeepQuestion =>
      'Vols conservar el que has dit per a més tard?';

  @override
  String get captureKeepTextQuestion =>
      'Vols conservar el text per a més tard?';

  @override
  String get captureRecordingFirst =>
      'Torna a provar aquesta gravació o descarta-la abans de gravar-ne una altra.';

  @override
  String get captureEmptyInput => 'Primer digues o escriu què has de fer.';

  @override
  String get captureSpeechStopped =>
      'S’ha deixat d’escoltar. Pots tornar a parlar o escriure.';

  @override
  String get captureNoSpeech => 'No t’he entès. Torna-ho a provar o escriu-ho.';

  @override
  String get captureCantListen =>
      'Ara no et puc escoltar en aquest telèfon. Toca Escriu.';

  @override
  String get captureIncompleteAudio =>
      'Aquesta gravació no es pot fer servir. Descarta-la i torna-la a dictar.';

  @override
  String get captureWriteFailed =>
      'No s’ha pogut conservar al telèfon. Torna-ho a provar abans de sortir.';

  @override
  String get captureStopFailed =>
      'No he pogut acabar d’escoltar. El que has dit abans es conserva.';

  @override
  String get captureDiscardFailed =>
      'No s’han pogut descartar les teves paraules. Es continuen conservant.';

  @override
  String get captureReviewWriteFailed =>
      'No s’han pogut conservar aquests canvis. Torna-ho a provar abans de sortir.';

  @override
  String get captureSaveFailed =>
      'No s’ha pogut afegir. Les paraules continuen aquí; torna-ho a provar.';

  @override
  String get captureSetupRequested =>
      'S’ha demanat la configuració de veu. Segueix les indicacions d’Android i toca Torna a comprovar-ho. Mentrestant pots continuar escrivint.';

  @override
  String get voiceSetupRequested =>
      'Segueix els passos d’Android i després toca Torna a comprovar-ho.';

  @override
  String get voiceSetupUnavailable =>
      'Aquest telèfon no ho pot configurar, així que TaskFlow ho fa en línia.';

  @override
  String get captureSetupUnavailable =>
      'La configuració de veu no està disponible aquí. Utilitza àudio desat o escriu.';

  @override
  String get voiceRecording => 'Gravació de veu';

  @override
  String get capturesCaughtUp => 'Tot al dia';

  @override
  String get capturesEmptyHelp =>
      'Aquí es guarden les gravacions i les tasques que deixis a mig fer.';

  @override
  String captureDraftSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sense afegir',
      one: '1 sense afegir',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pendents de revisar',
      one: '1 pendent de revisar',
    );
    return '$_temp0';
  }

  @override
  String captureAlsoOn(String date) {
    return 'també el $date';
  }

  @override
  String captureAlsoOnDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'també en $count dies més',
      one: 'també en un altre dia',
    );
    return '$_temp0';
  }

  @override
  String get captureConfirmDetails => 'Utilitza els detalls mostrats';

  @override
  String get captureNothingToReview => 'No queda res per revisar';

  @override
  String get captureRemovedDraftsHelp => 'No es farà cap canvi.';

  @override
  String get captureFinish => 'Fet';

  @override
  String get captureYourWords => 'Les teves paraules';

  @override
  String get captureCheckDetails => 'Revisa els detalls de sobre';

  @override
  String get captureUnderstanding => 'Entenent…';

  @override
  String get captureFailed =>
      'No ha funcionat. Les teves paraules continuen aquí; torna-ho a provar.';

  @override
  String get captureSlow => 'Està trigant més del normal.';

  @override
  String get captureSaveAsWritten => 'Desa-ho com a tasca';

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
      'Si vols fer canvis, demana-ho al propietari del projecte.';

  @override
  String get loadTaskError => 'No s’ha pogut carregar aquesta tasca';

  @override
  String deleteSeriesHelp(String title) {
    return 'Se suprimiran «$title» i totes les seves repeticions.';
  }

  @override
  String get viewOnlyTask => 'Només pots veure aquesta tasca.';

  @override
  String get stepUpdateError =>
      'No s’ha pogut actualitzar aquest pas. Torna-ho a provar.';

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
      'recognizerFinish': 'Últimes paraules després de Fet',
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
      'Només compres de prova. No es farà cap cobrament real. Una subscripció de prova activa dona dictat i espai per a fitxers il·limitats en aquesta versió de desenvolupament.';

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
  String get billingRestoreHelp =>
      'Ja tens una subscripció? Utilitza el mateix compte de la botiga i restaura les compres. Cancel·lar la renovació manté Pro disponible fins que acaba el període pagat.';

  @override
  String billingError(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'unsupportedPlatform':
          'Les subscripcions estan disponibles a l’aplicació d’Android.',
      'configuration':
          'Les subscripcions encara no estan disponibles. Torna-ho a provar més endavant.',
      'accountUnavailable':
          'No s’ha pogut connectar amb el teu compte de TaskFlow. Revisa la connexió i torna a obrir aquesta pantalla.',
      'network':
          'No s’ha pogut comprovar la subscripció. Revisa la connexió i torna a obrir aquesta pantalla.',
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
          'Compra rebuda. Pro s’activarà d’aquí a uns moments; si no, toca Restaura les compres.',
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
  String get invitationWaitingSignIn =>
      'Tens una invitació. Entra amb el correu on l’has rebuda.';

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
  String get forTeam => 'Totes';

  @override
  String get responsibility => 'Responsable';

  @override
  String get assignedToMe => 'Jo';

  @override
  String get assignedToGroup => 'Tothom';

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
  String groupArchivedForEveryone(String name) {
    return '«$name» arxivat per a tothom: ja no surt al calendari ni avisarà.';
  }

  @override
  String get groupDeleteHelp =>
      'Només pots suprimir un grup buit. Arxiva’l per conservar-ne els projectes i el contingut.';

  @override
  String get groupActionError =>
      'No s’ha pogut desar el canvi. Comprova la connexió i actualitza; els permisos poden haver canviat.';

  @override
  String get groupVoiceName => 'Nom per assignar-te per veu';

  @override
  String get groupVoiceHelp =>
      'Un nom opcional que els altres poden fer servir per assignar-te tasques per veu.';

  @override
  String get createGroup => 'Crea el grup';

  @override
  String get nextStep => 'Següent';

  @override
  String get enterName => 'Escriu un nom.';

  @override
  String groupRoleQuestion(String name) {
    return 'Què pot fer $name?';
  }

  @override
  String get groupInvited => 'Convidats';

  @override
  String get invitationPending => 'Pendent';

  @override
  String get loadFailed => 'No s’ha pogut carregar. Revisa la connexió.';

  @override
  String get projectDestination => 'On va aquest projecte?';

  @override
  String get projectNotifications => 'Novetats del projecte';

  @override
  String get updatesAll => 'Tots els canvis';

  @override
  String get updatesAssigned => 'Les meves assignacions';

  @override
  String get updatesMuted => 'Silenciat: sense novetats ni recordatoris';

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
  String get groupActivity => 'Activitat del grup';

  @override
  String get activityUnread => 'No llegida';

  @override
  String activityEntry(String action, String actor, String title) {
    String _temp0 = intl.Intl.selectLogic(action, {
      'created': '$actor ha creat: $title',
      'assigned': '$actor ha canviat el responsable de: $title',
      'unassigned': '$actor ha tret el responsable de: $title',
      'completed': '$actor ha completat: $title',
      'reopened': '$actor ha reobert: $title',
      'deleted': '$actor ha suprimit: $title',
      'shared': '$actor ha compartit: $title',
      'other': '$actor ha actualitzat: $title',
    });
    return '$_temp0';
  }

  @override
  String get captureSpeakingIsPro =>
      'Dictar una tasca forma part de TaskFlow Pro. La pots escriure aquí.';

  @override
  String get voiceProAction => 'Descobreix Pro';

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
  String invitationFrom(String sender, String name) {
    return '$sender et convida a «$name»';
  }

  @override
  String get invitationReviewHelp =>
      'En veuràs les tasques, les notes i els fitxers.';

  @override
  String get invitationUnavailable =>
      'Aquesta invitació no està disponible per a aquest compte. Comprova que hagis iniciat sessió amb el correu que l’ha rebuda o demana una invitació nova.';

  @override
  String get stagingInviteOnly =>
      'Aquesta versió de prova privada és per a persones convidades. Demana al responsable de TaskFlow una invitació a aquest correu.';

  @override
  String freeVoiceLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Et queden $count dictats gratuïts aquest mes',
      one: 'Et queda 1 dictat gratuït aquest mes',
      zero: 'Ja no et queden dictats gratuïts aquest mes',
    );
    return '$_temp0';
  }

  @override
  String freeVoiceUsedUp(String date) {
    return 'Fins al dia $date no tens dictats gratuïts.';
  }

  @override
  String freeVoiceUsedUpRecording(String date) {
    return 'La gravació es conserva. Es podrà entendre a partir del dia $date, o ara amb Pro.';
  }

  @override
  String get captureClose => 'Tanca';

  @override
  String freeVoiceStatus(int left, int limit, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'et queden $left',
      one: 'et queda 1',
    );
    return 'Dictats gratuïts: $_temp0 de $limit aquest mes. El dia $date en tindràs més.';
  }

  @override
  String get newTask => 'Tasca nova';

  @override
  String get pickDay => 'Tria un dia';

  @override
  String get removeTime => 'Treu l’hora';

  @override
  String createdBy(String name) {
    return 'Creada per $name';
  }

  @override
  String get createdByYou => 'Creada per tu';

  @override
  String freeVoiceNoticeTitle(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: 'Has fet servir els $limit dictats gratuïts d’aquest mes',
      one: 'Has fet servir el dictat gratuït d’aquest mes',
    );
    return '$_temp0';
  }

  @override
  String freeVoiceNoticeBody(int limit, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: 'El dia $date tindràs $limit dictats més.',
      one: 'El dia $date tindràs 1 dictat més.',
    );
    return 'Pots continuar creant tasques a mà, sense límit. $_temp0';
  }

  @override
  String get freeVoiceNoticeCreate => 'Crea una tasca';

  @override
  String storageUsage(int used, int limit) {
    return 'Fitxers: $used de $limit MB utilitzats';
  }

  @override
  String storageFull(int limit) {
    return 'El teu espai per a fitxers és ple ($limit MB).';
  }

  @override
  String get storageFullShared =>
      'L’espai per a fitxers d’aquest projecte és ple. El seu propietari pot treure fitxers per fer lloc.';

  @override
  String get storageSeeTasks => 'Mostra les tasques amb fitxers';

  @override
  String get tasksWithFiles => 'Tasques amb fitxers';

  @override
  String get tasksWithFilesHelp =>
      'Obre una tasca per treure els fitxers que ja no necessitis.';

  @override
  String tasksWithFilesRow(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fitxers',
      one: '1 fitxer',
    );
    return '$_temp0 · $size MB';
  }

  @override
  String get tasksWithFilesEmpty => 'Cap tasca no té fitxers.';

  @override
  String get projectPinned => 'Fixat';

  @override
  String projectSharedRole(String role) {
    return 'Compartit · $role';
  }

  @override
  String projectGroupSees(String group) {
    return 'Tothom a $group el veurà.';
  }

  @override
  String get deleteAccount => 'Suprimeix el compte';

  @override
  String get deleteAccountQuestion => 'Vols suprimir el compte?';

  @override
  String get deleteAccountIntro =>
      'Es suprimiran el compte de TaskFlow i les teves tasques, notes i fitxers a tots els dispositius. No es pot desfer.';

  @override
  String get deleteAccountWhatGoes => 'El que es suprimirà:';

  @override
  String deleteAccountTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasques',
      one: '1 tasca',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 nota',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fitxers',
      one: '1 fitxer',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountProjects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projectes',
      one: '1 projecte',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grups',
      one: '1 grup',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountKeptShared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tasques que vas afegir a projectes compartits, sense el teu nom',
      one: '1 tasca que vas afegir a projectes compartits, sense el teu nom',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountKeptFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fitxers que vas afegir a projectes compartits, sense el teu nom',
      one: '1 fitxer que vas afegir a projectes compartits, sense el teu nom',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountHandover(String kind, String name, String person) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'group': 'El grup «$name» i els seus projectes passaran a $person',
      'other': 'El projecte «$name» passarà a $person',
    });
    return '$_temp0';
  }

  @override
  String get deleteAccountWhatStays => 'El que es queda per als altres:';

  @override
  String get deleteAccountSubscription =>
      'Si pagues TaskFlow Pro a Google Play, suprimir el compte no cancel·la la subscripció.';

  @override
  String get deleteAccountSaveCopy => 'Desa abans una còpia de les tasques';

  @override
  String get deleteAccountCopySaved => 'Còpia desada';

  @override
  String get deleteAccountCopyNoFiles => 'La còpia no inclou els fitxers.';

  @override
  String get deleteAccountPasswordHelp =>
      'Per confirmar-ho, escriu la contrasenya.';

  @override
  String deleteAccountGoogleHelp(String email) {
    return 'Per confirmar-ho, tria $email quan Google t’ho demani. El compte de Google no se suprimeix.';
  }

  @override
  String deleteAccountGoogleInstead(String email) {
    return 'O confirma-ho amb Google i tria $email. El compte de Google no se suprimeix.';
  }

  @override
  String get deleteAccountConfirmGoogle => 'Confirma amb Google';

  @override
  String get deleteAccountGoogleConfirmed => 'Confirmat amb Google';

  @override
  String get deleteAccountButton => 'Suprimeix el meu compte';

  @override
  String get deleteAccountDeleting => 'S’està suprimint el compte…';

  @override
  String get deleteAccountWrongPassword =>
      'La contrasenya no és correcta. Si no te’n recordes, tanca la sessió i toca «Has oblidat la contrasenya?».';

  @override
  String get deleteAccountWrongPasswordGoogle =>
      'La contrasenya no és correcta. Si no te’n recordes, toca «Confirma amb Google».';

  @override
  String deleteAccountOtherGoogle(String email) {
    return 'Tria $email, el compte de Google amb què entres a TaskFlow.';
  }

  @override
  String get deleteAccountOffline =>
      'Necessites connexió per suprimir el compte. No s’ha suprimit res.';

  @override
  String get deleteAccountNoAnswer =>
      'No ha arribat cap resposta. Revisa la connexió i torna-ho a provar.';

  @override
  String get deleteAccountThrottled =>
      'Massa intents. Torna-ho a provar més tard.';

  @override
  String tooManyTriesWait(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Massa intents. Espera $minutes minuts i torna-ho a provar.',
      one: 'Massa intents. Espera un minut i torna-ho a provar.',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountPlanChanged =>
      'Alguna cosa ha canviat des que has obert aquesta pantalla. Revisa què passarà i torna a confirmar-ho.';

  @override
  String get deleteAccountChangedIntro =>
      'Alguna cosa ha canviat des que has obert aquesta pantalla:';

  @override
  String get deleteAccountChangedCheck => 'Revisa-ho i torna a confirmar-ho.';

  @override
  String get deleteAccountConfirmAgain => 'Torna a confirmar que ets tu.';

  @override
  String get deleteAccountFailed =>
      'No s’ha pogut suprimir el compte. Torna-ho a provar més tard.';

  @override
  String get webPageOpenError => 'No s’ha pogut obrir la pàgina.';

  @override
  String get accountDeleted => 'S’ha suprimit el compte.';

  @override
  String commandNewProject(String name) {
    return 'Projecte nou: $name';
  }

  @override
  String commandNewProjectChip(String name) {
    return '$name (nou)';
  }

  @override
  String get commandUseName => 'Fes servir aquest nom';

  @override
  String get commandRenameProject => 'Canvia el nom';

  @override
  String commandExistingProject(String name) {
    return 'Ja tens «$name»';
  }

  @override
  String commandExistingProjectTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les tasques hi van.',
      one: 'La tasca hi va.',
    );
    return '$_temp0';
  }

  @override
  String commandCreateProjectQuestion(String name) {
    return 'Vols crear el projecte «$name»?';
  }

  @override
  String commandCreateNamed(String name) {
    return 'Crea «$name»';
  }

  @override
  String get commandWhichProject => 'A quin projecte la poso?';

  @override
  String get commandOtherProject => 'Un altre projecte…';

  @override
  String commandCreateProjects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Crea $count projectes',
      one: 'Crea el projecte',
    );
    return '$_temp0';
  }

  @override
  String get commandAddAndChange => 'Afegeix i canvia';

  @override
  String get commandAddAndDelete => 'Afegeix i suprimeix';

  @override
  String get commandChangeAndDelete => 'Canvia i suprimeix';

  @override
  String get commandAddChangeAndDelete => 'Afegeix, canvia i suprimeix';

  @override
  String commandDontDelete(String title) {
    return 'No suprimeixis $title';
  }

  @override
  String commandDontChange(String title) {
    return 'No canviïs $title';
  }

  @override
  String get commandDontChangeAny => 'No en canviïs cap';

  @override
  String get commandDontDeleteAny => 'No en suprimeixis cap';

  @override
  String commandDontCreate(String name) {
    return 'No creïs $name';
  }

  @override
  String get commandWontDelete => 'No es suprimirà';

  @override
  String get commandWontChange => 'No es canviarà';

  @override
  String get commandWontCreate => 'No es crearà';

  @override
  String commandFindWords(String words) {
    return 'Tasques amb «$words»';
  }

  @override
  String commandFindProject(String name) {
    return 'Tasques de «$name»';
  }

  @override
  String commandFindPerson(String name) {
    return 'Tasques assignades a $name';
  }

  @override
  String get commandFindMine => 'Les teves tasques';

  @override
  String commandFindProjectPerson(String project, String name) {
    return 'Tasques de «$project» assignades a $name';
  }

  @override
  String commandFindProjectMine(String project) {
    return 'Les teves tasques de «$project»';
  }

  @override
  String commandFindPeriod(String from, String to) {
    return 'Del $from al $to';
  }

  @override
  String get commandFindOpen => 'Per fer';

  @override
  String get commandFindDone => 'Completades';

  @override
  String get commandCompleted => 'Completada';

  @override
  String commandFindNone(String words) {
    return 'No hi ha cap tasca amb «$words»';
  }

  @override
  String get commandFindNoneAtAll => 'No hi ha cap tasca';

  @override
  String commandMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I $count més',
      one: 'I 1 més',
    );
    return '$_temp0';
  }

  @override
  String commandShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostra’n $count més',
      one: 'Mostra’n 1 més',
    );
    return '$_temp0';
  }

  @override
  String commandOpenProject(String name) {
    return 'Obre «$name»';
  }

  @override
  String commandProjectNotFound(String name) {
    return 'No trobo el projecte «$name»';
  }

  @override
  String commandPersonNotFound(String name) {
    return 'No trobo $name';
  }

  @override
  String commandTaskNotFound(String words) {
    return 'No trobo cap tasca amb «$words»';
  }

  @override
  String get commandTaskNotFoundPlain => 'No trobo aquesta tasca';

  @override
  String commandViewOnly(String title) {
    return '«$title» és d’un projecte que només pots veure.';
  }

  @override
  String get commandWhichToChange => 'Quina vols canviar?';

  @override
  String get commandWhichToDelete => 'Quina vols suprimir?';

  @override
  String commandWillDelete(String title) {
    return 'Se suprimirà: $title';
  }

  @override
  String commandWillDeleteOn(String title, String date) {
    return 'Se suprimirà: $title ($date)';
  }

  @override
  String get commandChooseAnother => 'Tria’n una altra';

  @override
  String get commandNothingToChange => 'Ja és així.';

  @override
  String commandWhichDay(int hour, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      hour,
      locale: localeName,
      other: 'Quin dia, a les $time?',
      one: 'Quin dia, a la $time?',
    );
    return '$_temp0';
  }

  @override
  String commandMemberNotIn(String name, String project) {
    return '$name no és a «$project»';
  }

  @override
  String commandMemberNotInNew(String name, String project) {
    return '$name encara no és a «$project». Després, comparteix el projecte amb $name.';
  }

  @override
  String get commandAssignNeedsShared =>
      'Només es poden assignar tasques de projectes compartits.';

  @override
  String commandAmbiguousMember(String name) {
    return 'Hi ha diverses persones que es diuen $name.';
  }

  @override
  String commandTasksChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasques canviades',
      one: 'Tasca canviada',
    );
    return '$_temp0';
  }

  @override
  String commandTasksDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasques suprimides',
      one: 'Tasca suprimida',
    );
    return '$_temp0';
  }

  @override
  String commandProjectsCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projectes creats',
      one: 'Projecte creat',
    );
    return '$_temp0';
  }

  @override
  String commandChangeSemantics(String label, String before, String after) {
    return '$label: de $before a $after';
  }

  @override
  String commandNotesAdd(String text) {
    return 'S’afegeix a les notes: $text';
  }

  @override
  String get commandAssignee => 'Responsable';
}
