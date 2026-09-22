// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get note => 'Nota';

  @override
  String get noteEmptyBody => 'Sin texto añadido.';

  @override
  String get fileNone => 'No hay archivos adjuntos.';

  @override
  String get newNote => 'Nueva nota';

  @override
  String get editNote => 'Editar nota';

  @override
  String get noteTitle => 'Título de la nota';

  @override
  String get noteBody => 'Tu nota';

  @override
  String get notesHelp =>
      'Guarda información, ideas y material de referencia. Usa una tarea para algo que tengas que hacer.';

  @override
  String get notesEmpty => 'Un lugar para tus ideas';

  @override
  String get notesEmptyHelp =>
      'Escribe o dicta una nota. Añade enlaces o una lista de verificación cuando los necesites.';

  @override
  String get findNote => 'Buscar notas';

  @override
  String get reviewNote => 'Revisar nota';

  @override
  String get saveNote => 'Guardar nota';

  @override
  String get noteSaved => 'Nota guardada';

  @override
  String get recordNote => 'Dictar una nota';

  @override
  String get noteCaptureHelp =>
      'Conserva tus palabras en una nota. El texto se guarda en el teléfono hasta sincronizar; las grabaciones necesitan transcripción en línea.';

  @override
  String get noteHint => 'Ideas, detalles de reuniones, enlaces útiles…';

  @override
  String get deleteNoteQuestion => '¿Eliminar esta nota?';

  @override
  String get keepNote => 'Conservar nota';

  @override
  String get viewOnlyNote =>
      'Nota de solo lectura. El propietario de la lista gestiona el permiso de edición.';

  @override
  String get linkOpenError =>
      'No se ha podido abrir el enlace. Puedes copiarlo desde la nota.';

  @override
  String get noteLinks => 'Enlaces';

  @override
  String get plannedFor => 'Planificado para';

  @override
  String get plannedForHelp =>
      'Cuándo quieres hacer esta tarea. Puedes añadir una fecha límite en Más detalles.';

  @override
  String get planning => 'Duración y fecha límite';

  @override
  String get duration => 'Duración';

  @override
  String get durationUnset => 'Sin duración';

  @override
  String get durationEstimateHelp =>
      'Una estimación hasta que elijas una hora de inicio.';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get durationInput => 'Minutos (1–1440)';

  @override
  String get durationInvalid => 'Introduce un número entero de 1 a 1440.';

  @override
  String get removeDuration => 'Quitar duración';

  @override
  String get deadline => 'Fecha límite';

  @override
  String get deadlineUnset => 'Sin fecha límite';

  @override
  String get deadlineHelp =>
      'Debe estar terminada para esta fecha. Cambiar el inicio previsto mantiene esta fecha límite.';

  @override
  String get deadlineTime => 'Hora límite';

  @override
  String get deadlineEndDay => 'Antes de que termine el día';

  @override
  String get removeDeadline => 'Quitar fecha límite';

  @override
  String get deadlineRecurringHelp =>
      'La fecha límite se repite con cada instancia original. Mover una instancia mantiene su fecha límite; cambiar el inicio de la serie mantiene la primera fecha límite y cambia el margen de las siguientes.';

  @override
  String get deadlineLatePlan =>
      'El plan termina después de la fecha límite. Revisa el inicio o la duración.';

  @override
  String get deadlineOverdue => 'Fecha límite vencida';

  @override
  String deadlineLabel(String date) {
    return 'Vence $date';
  }

  @override
  String get reminderAnchor => 'Recordar con respecto a';

  @override
  String get reminderAnchorHelp =>
      'Un recordatorio por instancia, según la fecha elegida aquí.';

  @override
  String get dayTimeline => 'Horario del día';

  @override
  String get timelineFirstPlan => 'Ir al primer elemento con hora';

  @override
  String get timelineLimit =>
      'Se muestran los primeros 200 elementos con hora. Usa la agenda para ver todas las tareas.';

  @override
  String get timelineHelp =>
      'Trabajo planificado y eventos del teléfono. Las fechas límite indican cuándo debe estar terminado algo.';

  @override
  String get timelineUnblocked => 'Sin bloque de tiempo';

  @override
  String get timelineNoBlocks =>
      'No hay planes con hora para este día. Añade hora de inicio y duración para reservar un bloque.';

  @override
  String get timelinePoint => 'Sin duración · solo hora';

  @override
  String get timelineShortBlocks =>
      'Los eventos cortos tienen una zona táctil más grande; la barra de color muestra su duración real.';

  @override
  String timelineHours(int hours) {
    return '$hours horas en este día';
  }

  @override
  String get deviceCalendars => 'Calendarios del teléfono';

  @override
  String get deviceCalendarHelp =>
      'Consulta los eventos de los calendarios conectados a este teléfono junto a tus tareas.';

  @override
  String get deviceCalendarPrivacy =>
      'Elige qué calendarios mostrar. Los eventos son de solo lectura en TaskFlow y permanecen en este dispositivo; no se suben ni se envían a la IA. Gestiona sus recordatorios en tu aplicación de calendario.';

  @override
  String get calendarEnable => 'Conectar calendarios del teléfono';

  @override
  String get calendarDisable => 'Ocultar eventos del calendario';

  @override
  String get calendarChoose => 'Elegir calendarios';

  @override
  String get calendarChooseHelp =>
      'Selecciona hasta 50 calendarios. Las horas siguen la zona de tu dispositivo; los eventos de día completo conservan sus fechas originales.';

  @override
  String get calendarDenied =>
      'Permite el acceso al calendario para mostrar tus eventos. Tus tareas siguen funcionando sin él.';

  @override
  String get calendarBlocked =>
      'El acceso al calendario está desactivado. Puedes activarlo en los ajustes de la aplicación del teléfono.';

  @override
  String get calendarUnsupported =>
      'La visualización de calendarios del teléfono está disponible actualmente en Android.';

  @override
  String get calendarSettings => 'Abrir ajustes de la aplicación';

  @override
  String get calendarEmptySources =>
      'No hay calendarios visibles sincronizados en este teléfono. Conecta una cuenta en tu aplicación de calendario y actualiza aquí.';

  @override
  String get calendarRefresh => 'Actualizar calendarios';

  @override
  String get calendarClear => 'Borrar selección';

  @override
  String get calendarReadError =>
      'No se pudieron leer los eventos. Actualiza para volver a intentarlo; pueden faltar compromisos en esta vista.';

  @override
  String get calendarPreferenceError =>
      'No se pudo guardar esa selección. Vuelve a intentarlo. Puedes elegir hasta 50 calendarios.';

  @override
  String get calendarTruncated =>
      'Hay demasiados eventos para mostrarlos todos. Selecciona menos calendarios para ver los restantes.';

  @override
  String get calendarEvents => 'Eventos del calendario';

  @override
  String get calendarReadOnly => 'Evento del calendario · solo lectura';

  @override
  String get calendarNoEvents =>
      'No hay eventos de tus calendarios seleccionados este día.';

  @override
  String get calendarNoSelection =>
      'Elige calendarios para mostrar tus compromisos existentes.';

  @override
  String get calendarAllDay => 'Todo el día';

  @override
  String get calendarUntitled => 'Evento sin título';

  @override
  String get calendarShowAll => 'Ver todos los eventos';

  @override
  String get calendarOpenEvent => 'Abrir en la aplicación de calendario';

  @override
  String get calendarOpenError =>
      'La aplicación de calendario no pudo abrir este evento.';

  @override
  String get calendarEventGone =>
      'Este evento ya no está disponible en los calendarios seleccionados.';

  @override
  String get noScheduledTasks => 'No hay tareas de TaskFlow programadas';

  @override
  String get calendar => 'Calendario';

  @override
  String get tasks => 'Tareas';

  @override
  String get settings => 'Ajustes';

  @override
  String get yourCalendar => 'Tu calendario';

  @override
  String get inbox => 'Bandeja de entrada';

  @override
  String inboxCount(int count) {
    return 'Bandeja · $count';
  }

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get all => 'Todas';

  @override
  String get upcoming => 'Próximas';

  @override
  String get completed => 'Completadas';

  @override
  String get noDate => 'Sin fecha';

  @override
  String get anyTime => 'Sin hora';

  @override
  String get addTime => 'Añadir hora';

  @override
  String get chooseDate => 'Elegir fecha';

  @override
  String get chooseTime => 'Elegir hora';

  @override
  String get removeDate => 'Quitar fecha';

  @override
  String get removeTime => 'Quitar hora';

  @override
  String get newTask => 'Nueva tarea';

  @override
  String get editTask => 'Editar tarea';

  @override
  String get taskDetails => 'Detalles de la tarea';

  @override
  String get sayTask => 'Dictar una tarea';

  @override
  String get typeTasks => 'Escribir tareas';

  @override
  String get unfinishedCaptures => 'Capturas pendientes';

  @override
  String get captureDiagnostics => 'Diagnóstico de captura';

  @override
  String get lists => 'Listas';

  @override
  String get labels => 'Etiquetas';

  @override
  String get noList => 'Sin lista';

  @override
  String get priority => 'Prioridad';

  @override
  String get low => 'Baja';

  @override
  String get medium => 'Media';

  @override
  String get high => 'Alta';

  @override
  String get schedule => 'Programación';

  @override
  String get date => 'Fecha';

  @override
  String get time => 'Hora';

  @override
  String get repeat => 'Repetir';

  @override
  String get neverRepeat => 'No se repite';

  @override
  String get daily => 'Cada día';

  @override
  String get weekly => 'Cada semana';

  @override
  String get monthly => 'Cada mes';

  @override
  String get yearly => 'Cada año';

  @override
  String get noEndDate => 'Sin fecha de fin';

  @override
  String get notes => 'Notas';

  @override
  String get addNotes => 'Añadir notas';

  @override
  String get attachments => 'Adjuntos';

  @override
  String get checklist => 'Lista de pasos';

  @override
  String get complete => 'Completar';

  @override
  String get reopen => 'Reabrir';

  @override
  String get reschedule => 'Cambiar fecha';

  @override
  String get undo => 'Deshacer';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get keepChanges => 'Guardar cambios';

  @override
  String get createTask => 'Crear tarea';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get taskTitle => 'Título de la tarea';

  @override
  String get additionalNotes => 'Notas adicionales';

  @override
  String get moreDetails => 'Más detalles';

  @override
  String get fewerDetails => 'Menos detalles';

  @override
  String get appearance => 'Apariencia';

  @override
  String get chooseAppearance => 'Elige la apariencia';

  @override
  String get appearanceHelp => 'Elige un tema o usa el de tu dispositivo.';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get system => 'Sistema';

  @override
  String get yourSpace => 'Tu espacio';

  @override
  String get welcomeSettings => 'A tu gusto';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get notificationsHelp =>
      'Preferencias de avisos y próximos recordatorios';

  @override
  String get accountBackup => 'Cuenta y copia de seguridad';

  @override
  String get completedTasks => 'Tareas completadas';

  @override
  String get progressHelp => 'Un registro de tus avances';

  @override
  String get exportImport => 'Exportar e importar';

  @override
  String get exportImportHelp =>
      'Copias de TaskFlow e importación de CSV de Todoist';

  @override
  String get regionalSettings => 'Idioma y región';

  @override
  String get regionalSettingsHelp =>
      'Idioma, reloj, inicio de semana y zona de captura';

  @override
  String get language => 'Idioma';

  @override
  String get deviceDefault => 'Usar el dispositivo';

  @override
  String get clockFormat => 'Formato de hora';

  @override
  String get clock12 => 'Reloj de 12 horas';

  @override
  String get clock24 => 'Reloj de 24 horas';

  @override
  String get weekStart => 'Primer día de la semana';

  @override
  String get monday => 'Lunes';

  @override
  String get sunday => 'Domingo';

  @override
  String get saturday => 'Sábado';

  @override
  String get captureTimezone => 'Zona horaria de captura';

  @override
  String get timezoneHelp =>
      'Se usa para interpretar fechas en las nuevas capturas. Las tareas existentes y las capturas pendientes conservan su programación. Las horas se muestran en la zona de tu dispositivo.';

  @override
  String get searchTimezone => 'Buscar una zona horaria';

  @override
  String get regionHelp =>
      'Estas preferencias se guardan en este dispositivo. Cambiarlas no modifica las fechas ni las horas guardadas de tus tareas.';

  @override
  String get preferenceError =>
      'No se pudo guardar esta preferencia. Inténtalo de nuevo.';

  @override
  String timezoneFallback(String zone) {
    return 'No se puede obtener la zona del dispositivo. Las nuevas capturas usarán $zone.';
  }

  @override
  String get week => 'Semana';

  @override
  String get month => 'Mes';

  @override
  String get syncTasks => 'Sincronizar tareas';

  @override
  String get previousPeriod => 'Mes o semana anterior';

  @override
  String get nextPeriod => 'Mes o semana siguiente';

  @override
  String get moreClarity => 'Más claridad. Más espacio para vivir.';

  @override
  String get licenses => 'Licencias de código abierto';

  @override
  String get weekView => 'Vista semanal';

  @override
  String get monthView => 'Vista mensual';

  @override
  String get todayAgenda => 'Agenda de hoy';

  @override
  String get breathingRoom => 'Un momento de calma.';

  @override
  String get loadTasksError => 'No se pudieron cargar tus tareas';

  @override
  String get refreshCalendar => 'Prueba a actualizar el calendario.';

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get rememberPrompt => '¿Qué quieres recordar?';

  @override
  String get calendarEmpty =>
      'Pulsa Dictar una tarea y habla con naturalidad, o Nueva tarea para escribir. Las fechas son opcionales; las tareas sin fecha van a la bandeja de entrada.';

  @override
  String get planTask => 'Planificar una tarea';

  @override
  String get homeCapture => 'Captura desde la pantalla de inicio';

  @override
  String get homeCaptureHelp =>
      'Widget de micrófono, accesos directos y texto compartido en Android';

  @override
  String get homeCaptureInstructions =>
      'En Android, mantén pulsado el icono de TaskFlow para ver los accesos directos, o añade el widget de micrófono desde el lanzador. Comparte texto con TaskFlow desde otra aplicación.';

  @override
  String get widgetPickerHelp =>
      'Añade el widget de TaskFlow desde el selector de widgets del lanzador.';

  @override
  String get signInHelp => 'Inicia sesión para llevar tus tareas contigo';

  @override
  String get diagnosticsHelp =>
      'Tiempos y contadores locales, sin tus palabras';

  @override
  String get appearanceError =>
      'No se pudo guardar la preferencia de apariencia.';

  @override
  String get appearanceChangedError =>
      'La apariencia ha cambiado, pero no se pudo guardar la preferencia en este dispositivo.';

  @override
  String get switchLight => 'Cambiar al modo claro';

  @override
  String get switchDark => 'Cambiar al modo oscuro';

  @override
  String get list => 'Lista';

  @override
  String get archivedList => 'Lista archivada';

  @override
  String get yourList => 'Tu lista';

  @override
  String get yourTasks => 'Tus tareas';

  @override
  String get everythingToDo => 'Todo lo que quieres hacer';

  @override
  String get noDateNeeded => 'No hace falta una fecha';

  @override
  String get findTask => 'Buscar una tarea…';

  @override
  String get allTasks => 'Todas las tareas';

  @override
  String get highPriority => 'Prioridad alta';

  @override
  String get filterLabel => 'Filtrar por etiqueta';

  @override
  String get allLabels => 'Todas las etiquetas';

  @override
  String get noMatches => 'No hay tareas que coincidan';

  @override
  String get freshStart => 'Un nuevo comienzo';

  @override
  String get differentFilter => 'Prueba otra palabra o filtro.';

  @override
  String get listEmpty =>
      'Añade una tarea a esta lista. Tú eliges la fecha y el recordatorio.';

  @override
  String get tasksEmpty =>
      'Usa Dictar una tarea para hablar o Nueva tarea para escribir.\nAñade una fecha ahora o déjala para después.';

  @override
  String get inboxEmpty =>
      'Guarda aquí ideas y tareas hasta que elijas una fecha.\nEmpieza con Dictar una tarea o Nueva tarea.';

  @override
  String get savedOnDevice => 'Tus tareas guardadas siguen en tu dispositivo.';

  @override
  String get checkCaptures => 'Ver capturas pendientes';

  @override
  String get createVoiceTask => 'Crear una tarea con la voz';

  @override
  String get createTaskTooltip => 'Crear una tarea';

  @override
  String get reviewTask => 'Revisar tarea';

  @override
  String get fineTunePlan => 'Ajusta tu plan.';

  @override
  String get onYourMind => '¿Qué tienes en mente?';

  @override
  String get wordsPlan => 'Tus palabras, un plan claro.';

  @override
  String get seriesEdits =>
      'Los cambios se aplican a toda la tarea recurrente.';

  @override
  String get giveName => 'Ponle un nombre. Añade una fecha cuando quieras.';

  @override
  String get checkBeforeAdd =>
      'Revisa los detalles antes de añadirla al calendario.';

  @override
  String get titleRequired => 'Introduce un título para la tarea.';

  @override
  String get nameTask => '¿Qué te gustaría hacer?';

  @override
  String get chooseReminder => 'Elegir recordatorio';

  @override
  String get reminder => 'Recordatorio';

  @override
  String get off => 'Desactivado';

  @override
  String get useReminder => 'Usar recordatorio';

  @override
  String get dateForReminder => 'Añade una fecha para usar un recordatorio';

  @override
  String get chooseAlertTime => 'Elegir hora del aviso';

  @override
  String get defaultTime => 'Usar la hora predeterminada';

  @override
  String get reminderDefaultsError =>
      'No se pudieron cargar los valores predeterminados. Revisa los ajustes de notificaciones.';

  @override
  String get loadingReminders => 'Cargando los ajustes de recordatorios…';

  @override
  String get remindersDisabled =>
      'Los recordatorios están desactivados en este dispositivo';

  @override
  String get repeatInterval => 'Intervalo de repetición';

  @override
  String get repeatOn => 'Repetir los';

  @override
  String get repeatUsesStart =>
      'Usa el día de la semana de la fecha de inicio.';

  @override
  String get intervalRange => 'Elige un número del 1 al 99.';

  @override
  String get removeEndDate => 'Quitar la fecha de fin';

  @override
  String get keepRepeat => 'Guardar repetición';

  @override
  String get days => 'días';

  @override
  String get weeks => 'semanas';

  @override
  String get months => 'meses';

  @override
  String get years => 'años';

  @override
  String get deleteTask => 'Eliminar tarea';

  @override
  String get deleteTaskQuestion => '¿Eliminar la tarea?';

  @override
  String get keepTask => 'Conservar tarea';

  @override
  String get deleteTaskError =>
      'No se pudo eliminar esta tarea. Inténtalo de nuevo.';

  @override
  String get attachmentUnavailable =>
      'Este adjunto no está disponible en este dispositivo.';

  @override
  String get attachmentOpenError => 'No se pudo abrir este adjunto.';

  @override
  String get taskUnavailable => 'Tarea no disponible';

  @override
  String get occurrenceChanged => 'Repetición modificada';

  @override
  String get taskRemoved => 'Es posible que esta tarea se haya eliminado.';

  @override
  String get occurrenceSkipped =>
      'Esta fecha se ha omitido o ya no forma parte de la repetición.';

  @override
  String get editRepeating => 'Editar la tarea recurrente';

  @override
  String get nextStep => 'Tu próximo paso';

  @override
  String get moveError => 'No se pudo mover esta tarea. Inténtalo de nuevo.';

  @override
  String get occurrence => 'Repetición';

  @override
  String get starts => 'Comienza';

  @override
  String get inboxDate => 'Sin fecha · Bandeja de entrada';

  @override
  String get updateReminderError =>
      'No se pudo actualizar el recordatorio. Inténtalo de nuevo.';

  @override
  String get thisOccurrence => 'Esta repetición';

  @override
  String get wholeSeries => 'Toda la serie';

  @override
  String get skipOccurrence => 'Omitir esta repetición';

  @override
  String get resetOccurrence => 'Restablecer esta repetición';

  @override
  String get reset => 'Restablecer';

  @override
  String get captureThought => 'Captura una idea';

  @override
  String get captureIntro =>
      'Una tarea o varias. Habla con naturalidad o escribe tu plan.';

  @override
  String get stopDraft => 'Parar y crear borrador';

  @override
  String get recordTasks => 'Grabar tareas';

  @override
  String get stopRecording => 'Detener la grabación';

  @override
  String get puttingPlanTogether => 'Preparando tu plan…';

  @override
  String get recordingKept => 'Grabación guardada en este teléfono';

  @override
  String get tapSpeak => 'Pulsa para hablar';

  @override
  String get inputLevel => 'Nivel de entrada del micrófono';

  @override
  String get tapStopHelp => 'Pulsa Parar cuando termines. Hasta 60 segundos.';

  @override
  String get returnCaptureHelp =>
      'Puedes salir y volver. Las grabaciones pendientes se conservan.';

  @override
  String get speechOptions => 'Opciones de voz';

  @override
  String get onDeviceTranscript => 'Transcripción en directo en el dispositivo';

  @override
  String get onlineAudio => 'Audio guardado · transcripción en línea';

  @override
  String get liveTranscript => 'Transcripción en directo';

  @override
  String get savedAudio => 'Audio guardado';

  @override
  String get speechLanguage => 'Idioma de voz';

  @override
  String get deviceLanguage => 'Idioma del dispositivo';

  @override
  String get onDeviceUnavailable =>
      'La transcripción local no está disponible para este idioma en este dispositivo. Graba audio para procesarlo en línea o escribe.';

  @override
  String get setUpSpeech => 'Configurar la transcripción local';

  @override
  String get checkAgain => 'Comprobar de nuevo';

  @override
  String get holdTalk => 'Mantener pulsado para hablar';

  @override
  String get holdTalkHelp =>
      'Mantén pulsado el micrófono y suéltalo al terminar. También puedes tocarlo.';

  @override
  String get typePlan => 'O escribe tu plan';

  @override
  String get examplePlan =>
      'Médico el viernes a las 17:00. Llevar mis resultados. También comprar café.';

  @override
  String get tryRecording => 'Procesar esta grabación';

  @override
  String get reviewText => 'Revisar tareas del texto';

  @override
  String get discardCapture => 'Descartar captura';

  @override
  String get discardCaptureQuestion => '¿Descartar esta captura?';

  @override
  String get discard => 'Descartar';

  @override
  String get keep => 'Conservar';

  @override
  String get guestTrialHelp =>
      'Prueba la voz sin una cuenta. Los dispositivos de esta conexión comparten un pequeño límite diario.';

  @override
  String get capturePrivacy =>
      'La transcripción en directo usa el reconocimiento local cuando está disponible; ese modo no conserva audio. La extracción de tareas con IA necesita internet y envía tus palabras a Google. El audio guardado se transcribe en línea. Las capturas pendientes permanecen en este teléfono hasta que las guardes o descartes.';

  @override
  String get checkTasks => 'Revisa tus tareas';

  @override
  String get lookRight => '¿Está bien así?';

  @override
  String get finalSay => 'Toca un detalle para cambiarlo. Tú decides.';

  @override
  String get changePriority => 'Cambiar prioridad';

  @override
  String get changeRepeat => 'Cambiar repetición';

  @override
  String get confirmedDetails => 'He revisado esta tarea';

  @override
  String agendaCounts(int remaining, int done) {
    return '$remaining pendientes · $done completadas';
  }

  @override
  String completionCount(int done, int total) {
    return '$done de $total tareas completadas';
  }

  @override
  String pendingCaptureCount(int count) {
    return 'Capturas pendientes · $count';
  }

  @override
  String listeningSeconds(String time) {
    return 'Escuchando · $time';
  }

  @override
  String nativeSpeechHelp(String language) {
    return 'Transcripción local · $language. Las palabras aparecen abajo y se guardan mientras hablas.';
  }

  @override
  String repeatEvery(int interval, String unit) {
    return 'Cada $interval $unit';
  }

  @override
  String repeatEveryPrompt(String unit) {
    return 'Repetir cada… $unit';
  }

  @override
  String untilDate(String date) {
    return 'Hasta el $date';
  }

  @override
  String readyCount(int count) {
    return '$count listas para guardar';
  }

  @override
  String needsCheckCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas necesitan',
      one: '1 tarea necesita',
    );
    return '$_temp0 una revisión. Guarda las que estén listas cuando quieras.';
  }

  @override
  String priorityValue(String priority) {
    return 'Prioridad $priority';
  }

  @override
  String get pickDate => 'Elegir una fecha';

  @override
  String get typeTask => 'Escribir una tarea';

  @override
  String get addStepDialog => 'Añadir un paso';

  @override
  String get editStep => 'Editar paso';

  @override
  String get step => 'Paso';

  @override
  String get shortStep => 'Añade un paso breve.';

  @override
  String get keepStep => 'Guardar paso';

  @override
  String get repeatingSteps =>
      'Estos pasos se repiten con la tarea. Márcalos desde los detalles de cada repetición.';

  @override
  String get moveUp => 'Subir';

  @override
  String get moveDown => 'Bajar';

  @override
  String get removeStep => 'Eliminar paso';

  @override
  String get addChecklist => 'Añadir lista de pasos';

  @override
  String get addStep => 'Añadir paso';

  @override
  String get listUnavailable => 'Lista no disponible';

  @override
  String get moveToList => 'Mover a una lista';

  @override
  String get moveToListHelp =>
      'La fecha, el recordatorio y los detalles de la tarea se conservan.';

  @override
  String get archived => 'Archivada';

  @override
  String get createListHelp => 'Crea tu primera lista desde Tareas → Listas.';

  @override
  String get taskReopened => 'Tarea reabierta';

  @override
  String get taskCompleted => 'Tarea completada';

  @override
  String get undoError => 'No se pudo deshacer el cambio. Inténtalo de nuevo.';

  @override
  String get taskUpdateError =>
      'No se pudo actualizar esta tarea. Inténtalo de nuevo.';

  @override
  String get occurrenceSkippedNotice => 'Repetición omitida';

  @override
  String get originalRestored => 'Fecha original restaurada';

  @override
  String get movedInbox => 'Movida a la bandeja de entrada';

  @override
  String get scheduleUpdated => 'Programación actualizada';

  @override
  String get scheduleChangedAgain =>
      'La programación ha vuelto a cambiar. Abre la tarea para revisarla.';

  @override
  String get scheduleError =>
      'No se pudo cambiar la programación. Inténtalo de nuevo.';

  @override
  String get rescheduleRepeating => 'Cambiar la fecha de una tarea recurrente';

  @override
  String get rescheduleTask => 'Cambiar la fecha de la tarea';

  @override
  String get seriesRescheduleHelp =>
      'Cambia el inicio de la serie y restablece las fechas modificadas u omitidas. Mover a la bandeja de entrada detiene la repetición.';

  @override
  String get occurrenceRescheduleHelp =>
      'Las otras fechas de la serie no cambian.';

  @override
  String get saveSchedule => 'Guardar programación';

  @override
  String get restoreOriginal => 'Restaurar la fecha original';

  @override
  String get progressSmall => 'El progreso empieza poco a poco';

  @override
  String get completedEmpty =>
      'Aquí encontrarás todas las tareas que termines.';

  @override
  String get progressHeading => 'Mira todo lo que has avanzado.';

  @override
  String get completedLoadError =>
      'No se pudieron cargar las tareas completadas';

  @override
  String get tryLater => 'Inténtalo de nuevo en un momento.';

  @override
  String get suggestionApplied => 'Sugerencia de fecha aplicada';

  @override
  String get changeSeriesQuestion => '¿Cambiar la programación recurrente?';

  @override
  String get changeSeriesHelp =>
      'Esto restablece las fechas modificadas u omitidas según la nueva programación. Las fechas completadas permanecen en el historial.';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get resetSave => 'Restablecer y guardar';

  @override
  String get taskSavedInbox => 'Tarea guardada en la bandeja de entrada';

  @override
  String get taskAddedCalendar => 'Tarea añadida al calendario';

  @override
  String get changesSaved => 'Cambios guardados';

  @override
  String get taskSaveError =>
      'No se pudo guardar la tarea. Inténtalo de nuevo.';

  @override
  String get localAttachmentHelp =>
      'Por ahora los adjuntos permanecen en este teléfono. Iniciar sesión restaura las tareas, pero estos archivos no aparecerán en otro dispositivo.';

  @override
  String get choosePhoto => 'Elegir una foto';

  @override
  String get attachFile => 'Adjuntar un archivo';

  @override
  String get attachError =>
      'No se pudo adjuntar ese archivo. Inténtalo de nuevo.';

  @override
  String get capturedWords => 'Capturada a partir de tus palabras';

  @override
  String get titleRequiredField => 'Introduce un título para la tarea';

  @override
  String get keepAsTitle => 'Conservar como título';

  @override
  String get ambiguousTimeHelp =>
      'Elige a. m./p. m. o añade la hora. No se ha supuesto ninguna hora.';

  @override
  String get clearDate => 'Quitar fecha';

  @override
  String get optionalTime => 'Hora (opcional)';

  @override
  String get resetDateHelp => 'Restablece una fecha y guarda los cambios.';

  @override
  String get skipped => 'Omitida';

  @override
  String get theDetails => 'Los detalles';

  @override
  String get labelLimit =>
      'Usa hasta 10 etiquetas de un máximo de 32 caracteres cada una.';

  @override
  String get notesHint => 'Lo que quieras recordar…';

  @override
  String get addAttachment => 'Añadir adjunto';

  @override
  String get localAttachments => 'Los adjuntos permanecen en este dispositivo.';

  @override
  String get saving => 'Guardando…';

  @override
  String get saveChangesSentence => 'Guardar cambios';

  @override
  String useSchedule(String schedule) {
    return 'Usar $schedule';
  }

  @override
  String checklistCount(int done, int total) {
    return 'Pasos · $done/$total';
  }

  @override
  String checklistSemantics(int done, int total) {
    return 'Lista de pasos, $done de $total completados';
  }

  @override
  String get useDefault => 'Usar valor predeterminado';

  @override
  String get atScheduledTime => 'A la hora programada';

  @override
  String get hourBefore => '1 hora antes';

  @override
  String get dayBefore => '1 día antes';

  @override
  String get deviceOff => 'desactivado en el dispositivo';

  @override
  String get defaultChoice => 'predeterminado';

  @override
  String minutesBefore(int minutes) {
    return '$minutes minutos antes';
  }

  @override
  String reminderValue(String value) {
    return 'Recordatorio: $value';
  }

  @override
  String get fileLocal => 'Solo en este dispositivo';

  @override
  String get fileQueued => 'Subida pendiente';

  @override
  String get fileBackedUp => 'Guardado en tu cuenta';

  @override
  String get fileDownloadAvailable => 'Disponible para descargar';

  @override
  String get fileMissing => 'Archivo no disponible en este dispositivo';

  @override
  String get fileRemovalPending => 'Eliminación pendiente';

  @override
  String get fileUpload => 'Subir';

  @override
  String get fileDownload => 'Descargar';

  @override
  String get fileOpen => 'Abrir';

  @override
  String get fileRetry => 'Reintentar transferencia';

  @override
  String get fileRemove => 'Eliminar archivo adjunto';

  @override
  String get fileRemoveQuestion => '¿Eliminar este archivo adjunto?';

  @override
  String get fileRemoveHelp =>
      'Se eliminará de la tarea y, si lo has subido, de tus otros dispositivos al sincronizar. Tu archivo original no se elimina.';

  @override
  String get yourAccount => 'Tu cuenta';

  @override
  String get accountHeading => 'Tu propio espacio.';

  @override
  String get backupHeading => 'Tus planes, siempre contigo.';

  @override
  String get accountBackupHelp =>
      'Las tareas y notas se guardan en este teléfono y se copian a tu cuenta cuando hay conexión. Los archivos nuevos se suben después de guardar; consulta su estado en los detalles. Para subir archivos locales anteriores, pulsa Subir.';

  @override
  String get accountUpToDate => 'Tus tareas y notas están actualizadas.';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get importLocalItems => 'Importar tareas y notas locales';

  @override
  String get importLocalItemsQuestion => '¿Importar tareas y notas locales?';

  @override
  String importLocalItemsHelp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mueve $count elementos de este teléfono a tu cuenta',
      one: 'Mueve 1 elemento de este teléfono a tu cuenta',
    );
    return '$_temp0 para guardar tus tareas y notas. Los archivos adjuntos permanecen en este teléfono hasta que elijas Subir en los detalles.';
  }

  @override
  String get importItems => 'Importar';

  @override
  String get noLocalItems => 'No hay tareas ni notas locales que importar.';

  @override
  String itemsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos importados.',
      one: '1 elemento importado.',
    );
    return '$_temp0';
  }

  @override
  String get connectionDetails => 'Detalles de conexión';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get recoveryHeading => 'Recupera tu acceso.';

  @override
  String get registerHeading => 'Un espacio para tus planes.';

  @override
  String get signInHeading => 'Te damos la bienvenida.';

  @override
  String get recoveryHelp =>
      'Solicita un correo de recuperación y usa el código para elegir una nueva contraseña.';

  @override
  String get accountSignInHelp =>
      'Inicia sesión para guardar tus tareas y notas en tu cuenta y ampliar tu límite de captura por voz.';

  @override
  String get email => 'Correo electrónico';

  @override
  String get enterEmail => 'Introduce tu correo electrónico';

  @override
  String get recoveryCode => 'Código de recuperación';

  @override
  String get recoveryCodeHelp => 'Déjalo vacío para solicitar un correo.';

  @override
  String get newPassword => 'Nueva contraseña';

  @override
  String get password => 'Contraseña';

  @override
  String get passwordHelp => 'Al menos 12 caracteres';

  @override
  String get passwordTooShort => 'Usa al menos 12 caracteres';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get continueRecovery => 'Continuar recuperación';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get alreadyHaveAccount => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get createAnAccount => 'Crear una cuenta';

  @override
  String get backToSignIn => 'Volver a iniciar sesión';

  @override
  String get forgotPassword => '¿Has olvidado tu contraseña?';

  @override
  String get accountGuestHelp =>
      'También puedes usar TaskFlow sin cuenta. Tus tareas y notas locales permanecen en este teléfono.';

  @override
  String get connectionSettings => 'Ajustes de conexión';

  @override
  String get backendAddress => 'Dirección del servidor';

  @override
  String get backendAddressHelp =>
      'Emulador: http://10.0.2.2:8088\nTeléfono: la IP local de tu ordenador en la misma red wifi.';

  @override
  String get recoveryEmailRequested =>
      'Si la cuenta existe, se ha enviado un correo de recuperación.';

  @override
  String get passwordResetComplete =>
      'Contraseña actualizada. Inicia sesión con tu nueva contraseña.';

  @override
  String get newList => 'Nueva lista';

  @override
  String get editList => 'Editar lista';

  @override
  String get listName => 'Nombre';

  @override
  String get listNameHint => 'Trabajo, Personal, Compras…';

  @override
  String get listNameRequired => 'Pon un nombre a tu lista.';

  @override
  String get colorTeal => 'Verde azulado';

  @override
  String get colorBlue => 'Azul';

  @override
  String get colorViolet => 'Violeta';

  @override
  String get colorAmber => 'Ámbar';

  @override
  String get colorRose => 'Rosa';

  @override
  String get saveList => 'Guardar lista';

  @override
  String get listSaveError =>
      'No se pudo guardar la lista. Vuelve a intentarlo.';

  @override
  String get listRestored => 'Lista restaurada';

  @override
  String get listArchivedHelp => 'Lista archivada. Contenido conservado.';

  @override
  String get listUpdateError =>
      'No se pudo actualizar la lista. Vuelve a intentarlo.';

  @override
  String get chooseListDetails => 'Elige los detalles de la lista';

  @override
  String listConflictHelp(String local, String remote) {
    return 'Este teléfono: $local\n\nOtro dispositivo: $remote\n\nEl contenido de las tareas y notas no cambiará.';
  }

  @override
  String get later => 'Más tarde';

  @override
  String get useOtherDevice => 'Usar el otro dispositivo';

  @override
  String get useThisPhone => 'Usar este teléfono';

  @override
  String get listResolveError =>
      'No se pudo resolver el conflicto de la lista. Vuelve a intentarlo.';

  @override
  String get retryLists => 'Reintentar listas';

  @override
  String get refreshLists => 'Actualizar listas e invitaciones';

  @override
  String get listsHelp =>
      'Organiza el trabajo, tu vida personal y lo demás en sus propias listas. La bandeja de entrada sigue reuniendo las tareas sin fecha.';

  @override
  String get listsEmptyTitle => 'Un lugar para cada parte de tu vida';

  @override
  String get listsEmptyHelp =>
      'Empieza con Trabajo, Personal o Compras. Puedes mover las tareas cuando quieras.';

  @override
  String get roleOwner => 'Propietario';

  @override
  String get roleEditor => 'Editor';

  @override
  String get roleViewer => 'Lector';

  @override
  String sharedListRole(String role) {
    return '$role · compartida';
  }

  @override
  String get listConflict => 'Cambió en otro dispositivo · elige los detalles';

  @override
  String get archivedListHelp => 'Archivada · tareas y notas disponibles';

  @override
  String listItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas y notas',
      one: '1 tarea o nota',
      zero: 'Sin tareas ni notas',
    );
    return '$_temp0';
  }

  @override
  String manageItem(String name) {
    return 'Gestionar $name';
  }

  @override
  String get restoreList => 'Restaurar lista';

  @override
  String get archiveList => 'Archivar lista';

  @override
  String get sharingAndPeople => 'Compartir y gestionar personas';

  @override
  String get chooseDetails => 'Elegir detalles';

  @override
  String get sharedListVisibility =>
      'Compartida · todas las personas de esta lista pueden ver sus tareas, notas y archivos subidos';

  @override
  String get invitationCode => 'Código de invitación';

  @override
  String get invitationCodeHelp =>
      'Entrega este código a la persona invitada por un medio de confianza. Para aceptar, necesita el código y la cuenta de TaskFlow invitada. El código solo se muestra ahora; reemplazar una invitación invalida su código anterior.';

  @override
  String get accountChanged => 'La cuenta ha cambiado.';

  @override
  String get copyCode => 'Copiar código';

  @override
  String get done => 'Listo';

  @override
  String get sharingUpdateError =>
      'No se pudo actualizar el acceso compartido. Comprueba la conexión y vuelve a intentarlo.';

  @override
  String get inviteToList => 'Invitar a esta lista';

  @override
  String get inviteHelp =>
      'Tras aceptar, podrán ver todas las tareas, notas y archivos subidos de esta lista. La invitación aparece en su cuenta de TaskFlow; no se envía ningún correo. Entrégales el código que aparece a continuación. Caduca en 7 días.';

  @override
  String get inviteeEmail => 'Correo de su cuenta';

  @override
  String get enterEmailAddress => 'Introduce un correo electrónico.';

  @override
  String get access => 'Acceso';

  @override
  String get sharingRolesHelp =>
      'Los editores pueden añadir, cambiar, completar y eliminar tareas y archivos. Solo el propietario gestiona la lista y las personas. Las tareas compartidas permanecen en esta lista; al exportarlas se crea una copia personal.';

  @override
  String get createInvitation => 'Crear invitación';

  @override
  String get listSharing => 'Compartir lista';

  @override
  String get sharingLoadError => 'No se pudo cargar el acceso compartido.';

  @override
  String get retry => 'Reintentar';

  @override
  String yourRole(String role) {
    return 'Tu rol: $role';
  }

  @override
  String get sharingHelp =>
      'Comparte compras y tareas de casa. Los cambios se sincronizan cuando la aplicación se conecta o cuando actualizas.';

  @override
  String get invitePerson => 'Invitar a una persona';

  @override
  String get people => 'Personas';

  @override
  String get noOtherMembers => 'Por ahora, solo tú tienes acceso.';

  @override
  String get makeEditor => 'Dar permiso de edición';

  @override
  String get makeViewer => 'Dar permiso de lectura';

  @override
  String get removeAccess => 'Retirar acceso';

  @override
  String get removeAccessHelp =>
      'Esta persona perderá el acceso a la lista y a sus tareas, notas y archivos. Sus cambios compartidos pendientes se eliminarán en la próxima sincronización correcta.';

  @override
  String get pendingInvitations => 'Invitaciones pendientes';

  @override
  String pendingRole(String role) {
    return '$role · pendiente';
  }

  @override
  String get revokeInvitation => 'Revocar invitación';

  @override
  String get replaceInvitationHelp =>
      'Pulsa una invitación pendiente para reemplazar su código.';

  @override
  String get howSharingWorks => 'Cómo funciona el acceso compartido';

  @override
  String get sharedDataHelp =>
      'Se comparten tareas, notas y archivos subidos. Los editores pueden modificarlos o eliminarlos; los lectores pueden consultarlos. Las opciones de recordatorio se comparten, pero cada teléfono debe activar sus propias notificaciones.';

  @override
  String get sharingRemovalHelp =>
      'Al salir o perder el acceso, las tareas y notas compartidas, los cambios pendientes y las copias descargadas se eliminarán de este teléfono en la próxima sincronización correcta. No se pueden borrar a distancia los dispositivos sin conexión ni las copias ya exportadas.';

  @override
  String get deleteList => 'Eliminar lista';

  @override
  String get deleteListHelp =>
      '¿Eliminar esta lista y todas sus tareas, notas y archivos subidos para todas las personas? No se puede deshacer.';

  @override
  String get deleteListForEveryone => 'Eliminar la lista para todos';

  @override
  String get leaveList => 'Salir de la lista';

  @override
  String get leaveListHelp =>
      'Las tareas, notas y archivos compartidos y los cambios pendientes se eliminarán de este teléfono. Los demás miembros conservan la lista.';

  @override
  String get enterInvitationCode => 'Introduce el código de invitación';

  @override
  String get requestInvitationCodeHelp =>
      'Pide al propietario de la lista el código que recibió al invitarte.';

  @override
  String get invitationCodeRequired => 'Pega el código de invitación completo.';

  @override
  String get joinList => 'Unirse a la lista';

  @override
  String get invitationResponseError =>
      'No se pudo responder. Vuelve a intentarlo cuando haya conexión.';

  @override
  String get retryInvitations => 'Reintentar invitaciones';

  @override
  String get invitations => 'Invitaciones';

  @override
  String joinListHelp(String role) {
    return 'Únete con el rol de $role. Las tareas, notas y archivos compartidos se sincronizarán con tu cuenta.';
  }

  @override
  String get acceptInvitation => 'Aceptar invitación';

  @override
  String get decline => 'Rechazar';

  @override
  String get fileEmpty =>
      'No hay archivos adjuntos. Añade un archivo al editar.';

  @override
  String get fileLoadError =>
      'No se pudo cargar el estado de los archivos. Vuelve a intentarlo.';

  @override
  String get fileActionError =>
      'No se pudo completar la acción. Tu tarea está guardada; vuelve a intentarlo.';

  @override
  String get fileSignInHelp =>
      'Inicia sesión para subir tus archivos y recuperarlos en otro dispositivo.';

  @override
  String get fileUploadHelp =>
      'Los archivos nuevos se suben a tu cuenta al guardar: hasta 6 MiB por archivo y 64 MiB por cuenta. Los archivos locales anteriores permanecen aquí hasta que elijas Subir en los detalles de la tarea.';

  @override
  String get fileLocalHelp =>
      'Los archivos permanecen en este dispositivo hasta que inicies sesión y elijas Subir en los detalles de la tarea. Hasta 6 MiB por archivo.';

  @override
  String get fileLimit =>
      'Elige un archivo no vacío de hasta 6 MiB. Puedes adjuntar hasta 20 archivos por tarea.';

  @override
  String get fileManageHelp =>
      'Abre los detalles de la tarea para descargar, subir o eliminar archivos de tu cuenta.';

  @override
  String get notificationLoadError =>
      'No se pudieron cargar los ajustes de notificaciones. Inténtalo de nuevo.';

  @override
  String get notificationSaveError =>
      'No se pudieron guardar los ajustes de recordatorios. Inténtalo de nuevo.';

  @override
  String get enableReminders => 'Activar recordatorios';

  @override
  String get deviceReminderScope =>
      'Para esta cuenta en este dispositivo. Las opciones de cada tarea se sincronizan; los ajustes del dispositivo se quedan aquí.';

  @override
  String get mobileNotificationsOnly =>
      'Notificaciones solo en dispositivos móviles';

  @override
  String get notificationPermissionOn => 'Permiso del sistema activado';

  @override
  String get notificationPermissionOff => 'Permiso del sistema desactivado';

  @override
  String get preciseAlarmsAvailable => 'Acceso a alarmas exactas disponible';

  @override
  String get approximateAlarmsHelp =>
      'Los avisos son aproximados hasta que actives el acceso a alarmas exactas';

  @override
  String get openSystemSettings => 'Abrir ajustes del sistema';

  @override
  String get allowPreciseAlarms => 'Permitir alarmas exactas';

  @override
  String get taskDefaults => 'Opciones predeterminadas';

  @override
  String get timedTasks => 'Tareas con hora';

  @override
  String get dateOnlyTasks => 'Tareas sin hora';

  @override
  String get dailyCheckIns => 'Revisiones diarias';

  @override
  String get dailyCheckInsHelp => 'Un aviso para revisar tus tareas actuales.';

  @override
  String get morningCheckIn => 'Mañana';

  @override
  String get eveningCheckIn => 'Tarde';

  @override
  String get upcomingAlerts => 'Próximos avisos';

  @override
  String get scheduledAlertHelp =>
      'Programado significa que el teléfono ha aceptado el aviso. Las restricciones de batería, los ajustes del sistema y el cierre forzado pueden retrasarlo o impedir su entrega.';

  @override
  String get androidAlertRefreshHelp =>
      'La programación se actualiza al usar la app y mediante una tarea cada hora en segundo plano, cuando Android lo permite.';

  @override
  String get backgroundAlertRefreshHelp =>
      'La programación se actualiza al usar la app y cuando el sistema permite actualizar en segundo plano.';

  @override
  String get noUpcomingAlerts =>
      'No hay próximos avisos. Elige un recordatorio en una tarea con fecha.';

  @override
  String get repeatsDaily => 'se repite cada día';

  @override
  String get retryScheduling => 'Actualizar y reintentar';

  @override
  String get alertPending => 'pendiente';

  @override
  String get alertScheduled => 'programado';

  @override
  String get alertApproximate => 'aproximado';

  @override
  String get alertBlocked => 'bloqueado';

  @override
  String get alertFailed => 'no programado';

  @override
  String get alertInactive => 'inactivo';

  @override
  String get alertElapsed => 'pasado';

  @override
  String get reminderPermissionError =>
      'Las notificaciones están desactivadas en los ajustes del sistema.';

  @override
  String get reminderScheduleError =>
      'El teléfono no pudo programar este aviso. Reinténtalo desde Ajustes.';

  @override
  String get reminderBackgroundError =>
      'No se pudo completar la actualización en segundo plano. Abre TaskFlow para reintentarlo.';

  @override
  String get reminderBackgroundUnavailable =>
      'La actualización automática en segundo plano no está disponible. Los avisos se actualizan al abrir TaskFlow.';

  @override
  String get reminderActionError =>
      'No se pudo completar la acción del aviso. Abre la tarea para reintentarlo.';

  @override
  String get reminderSetupError =>
      'No se pudo completar la configuración de notificaciones. Reinténtalo desde Ajustes.';

  @override
  String get reminderAccountError =>
      'No se pudieron actualizar los recordatorios de la cuenta. Abre los ajustes de notificaciones para reintentarlo.';

  @override
  String get reminderRefreshError =>
      'No se pudieron actualizar los recordatorios. Tus tareas están guardadas; reinténtalo desde los ajustes de notificaciones.';

  @override
  String get transferError =>
      'No se pudo completar la operación. Tus tareas y notas no han cambiado. Inténtalo de nuevo.';

  @override
  String get exportSaved => 'Archivo exportado. Guárdalo en un lugar privado.';

  @override
  String get keepYourTasks => 'Llévate tus tareas.';

  @override
  String get archiveContentsHelp =>
      'Las exportaciones de TaskFlow incluyen tareas, notas, fechas, cambios de repeticiones, progreso, listas de pasos, etiquetas y listas personales. Se incluyen los nombres de los adjuntos, pero no su contenido, las credenciales de la cuenta, los ajustes del dispositivo ni las capturas sin terminar.';

  @override
  String get exportTaskFlowFile => 'Exportar archivo TaskFlow';

  @override
  String get chooseImportFile => 'Elegir archivo para importar';

  @override
  String get chooseImportFileHelp =>
      'Elige una exportación JSON de TaskFlow o un CSV de proyecto de Todoist (hasta 32 MB y 5.000 tareas y notas). Podrás revisarlo antes de importar.';

  @override
  String get importPreview => 'Vista previa de importación';

  @override
  String get importCopiesHelp =>
      'Las tareas y notas seleccionadas y las listas del archivo se añaden como copias personales. Se conserva el contenido existente. Si vuelves a importar este mismo archivo, se omiten los registros ya importados en este teléfono; un archivo modificado o exportado de nuevo cuenta como una importación diferente.';

  @override
  String get listsIncluded => 'Listas incluidas';

  @override
  String get archivedPersonalCopy => 'Copia personal archivada';

  @override
  String get personalCopy => 'Copia personal';

  @override
  String get alreadyImported => 'Ya importado en este teléfono';

  @override
  String get taskFlowExportSource => 'Exportación de TaskFlow';

  @override
  String get todoistCsvSource => 'CSV de proyecto de Todoist';

  @override
  String deferredAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hay $count avisos posteriores fuera de la programación actual.',
      one: 'Hay 1 aviso posterior fuera de la programación actual.',
    );
    return '$_temp0 La próxima actualización añadirá los primeros que quepan.';
  }

  @override
  String turnOffReminder(String title) {
    return 'Desactivar $title';
  }

  @override
  String importResult(int items, int lists) {
    String _temp0 = intl.Intl.pluralLogic(
      items,
      locale: localeName,
      other: '$items elementos',
      one: '1 elemento',
    );
    String _temp1 = intl.Intl.pluralLogic(
      lists,
      locale: localeName,
      other: '$lists listas',
      one: '1 lista',
    );
    return 'Se han añadido $_temp0 y $_temp1.';
  }

  @override
  String importSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos ya importados',
      one: '1 elemento ya importado',
    );
    return 'Se han omitido $_temp0.';
  }

  @override
  String importCounts(String source, int tasks, int notes, int lists) {
    return '$source · $tasks tareas · $notes notas · $lists listas';
  }

  @override
  String cannotImport(String reason) {
    return 'No se puede importar: $reason';
  }

  @override
  String importSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos seleccionados',
      one: '1 elemento seleccionado',
    );
    return 'Importar $_temp0 y listas';
  }

  @override
  String importRow(int row) {
    return 'Registro $row';
  }

  @override
  String get archiveFileTooLarge => 'Elige un archivo de menos de 32 MB.';

  @override
  String get archiveUnsupportedArchive =>
      'Este archivo no es una exportación compatible de TaskFlow (versiones 1 y 2).';

  @override
  String get archiveInvalidList => 'Los datos de la lista no son válidos.';

  @override
  String get archiveDuplicateLists =>
      'Hay identificadores de lista duplicados.';

  @override
  String get archiveInvalidListStyle =>
      'El color o el estado de archivo de la lista no es válido.';

  @override
  String get archiveInvalidTask => 'El registro de tarea no es válido.';

  @override
  String get archiveDuplicateTask =>
      'El identificador de tarea está duplicado.';

  @override
  String get archiveInvalidAttachments =>
      'Los datos de los adjuntos no son válidos.';

  @override
  String get archiveMissingList =>
      'La tarea hace referencia a una lista que no está en el archivo.';

  @override
  String get archiveInvalidTaskFields =>
      'Los campos de la tarea no son válidos.';

  @override
  String get archiveUnsupportedKind =>
      'El tipo de tarea o nota no es compatible.';

  @override
  String get archiveInvalidCompletion =>
      'El estado de finalización no es válido.';

  @override
  String get archiveTwoSchedules =>
      'Una tarea no puede tener dos fechas programadas.';

  @override
  String get archiveTwoDeadlines => 'Elige un plazo con hora o solo con fecha.';

  @override
  String get archiveInvalidReminderDate =>
      'Elige una fecha disponible para el recordatorio.';

  @override
  String get archiveUnsupportedRepeat =>
      'La regla de repetición no es compatible.';

  @override
  String get archiveWeekdaysNeedWeekly =>
      'Los días de la semana requieren una repetición semanal.';

  @override
  String get archiveRepeatNeedsStart =>
      'Una tarea repetida necesita una fecha de inicio.';

  @override
  String get archiveInvalidOccurrence =>
      'El cambio de una repetición no es válido.';

  @override
  String get archiveDuplicateOccurrence =>
      'Hay cambios de repetición duplicados.';

  @override
  String get archiveInvalidSkipped => 'La fecha omitida no es válida.';

  @override
  String get archiveInvalidOccurrenceSchedule =>
      'La fecha de la repetición no es válida.';

  @override
  String get archiveRepeatSettingsNeedRepeat =>
      'Los ajustes de repetición requieren una tarea repetida.';

  @override
  String get archiveRepeatUsesCompletedDates =>
      'Las tareas repetidas usan fechas de finalización individuales.';

  @override
  String get archiveInvalidChecklist => 'El paso de la lista no es válido.';

  @override
  String get archiveDuplicateChecklist =>
      'Hay identificadores de pasos duplicados.';

  @override
  String get archiveInvalidChecklistProgress =>
      'El progreso de la lista de pasos no es válido.';

  @override
  String get archiveRepeatEndBeforeStart =>
      'El final de la repetición es anterior al inicio.';

  @override
  String get archiveOccurrenceOutsideRepeat =>
      'Un cambio de fecha queda fuera de esta regla de repetición.';

  @override
  String get archiveExportTooLarge =>
      'La exportación supera el límite de 32 MB o 5.000 tareas y notas.';

  @override
  String get archiveInvalidDateFormat =>
      'Las fechas deben usar el formato AAAA-MM-DD.';

  @override
  String get archiveInvalidDate => 'La fecha del calendario no es válida.';

  @override
  String get archiveMissingTimezone =>
      'Las fechas con hora requieren formato ISO y un desplazamiento de zona horaria.';

  @override
  String get archiveInvalidClock => 'La hora no es válida.';

  @override
  String get archiveInvalidOffset =>
      'El desplazamiento de zona horaria no es válido.';

  @override
  String get archiveInvalidTimedDate => 'La fecha con hora no es válida.';

  @override
  String get archiveFileUnreadable =>
      'No se pudo leer este archivo. Elige una copia local.';

  @override
  String get archiveEmptyCsv => 'Este CSV está vacío.';

  @override
  String get archiveCsvHeader =>
      'Elige un CSV de proyecto de Todoist con columnas TYPE y CONTENT.';

  @override
  String get archiveCsvTaskLimit =>
      'Elige un CSV con un máximo de 5.000 tareas.';

  @override
  String get archiveCsvPriority => 'La prioridad debe estar entre 1 y 4.';

  @override
  String get archiveCsvIndent => 'El nivel de sangría debe estar entre 1 y 4.';

  @override
  String get archiveCsvRecordLimit => 'Este CSV tiene demasiados registros.';

  @override
  String get archiveCsvQuoting =>
      'Las comillas del CSV no están bien formadas.';

  @override
  String get archiveCsvUnclosedQuote =>
      'Hay un campo entre comillas sin cerrar en el CSV.';

  @override
  String get archiveNotesTooLong =>
      'La tarea y sus comentarios superan los 8.000 caracteres de notas.';

  @override
  String get archiveInvalidFile =>
      'El archivo no contiene JSON o texto UTF-8 válido.';

  @override
  String get archiveUnknownFields =>
      'Se omitirán los campos de tarea no reconocidos.';

  @override
  String get archivePersonalCopies =>
      'La importación crea copias personales nuevas. No incluye el acceso a cuentas, los archivos, los ajustes de notificaciones ni las capturas sin terminar.';

  @override
  String get archiveCsvPriorities =>
      'Las prioridades 3 y 4 de Todoist pasan a Baja. Las subtareas se convierten en tareas independientes.';

  @override
  String get archiveCsvDates =>
      'Solo se programan fechas ISO y horas con zona horaria explícita. Las demás expresiones de fecha se conservan en las notas para revisarlas.';

  @override
  String get archiveCsvPersonalCopies =>
      'Se crean copias personales. No se transfieren las asignaciones, los archivos ni el acceso compartido. Los CSV de proyecto de Todoist pueden omitir las tareas completadas.';

  @override
  String get archiveReviewSchedule =>
      'La fecha original necesita revisión; esta tarea irá a la Bandeja de entrada.';

  @override
  String get archiveFlattenedSubtasks =>
      'Las subtareas pasarán a ser tareas independientes.';

  @override
  String get archiveInlineLabels =>
      'Las @etiquetas del texto se conservan en el título.';

  @override
  String archiveAttachmentsOmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'el contenido de $count archivos adjuntos',
      one: '1 archivo adjunto',
    );
    return 'No se incluye $_temp0.';
  }

  @override
  String archiveInvalidCollection(String field, int max) {
    return '$field: valor no válido (máximo $max).';
  }

  @override
  String archiveInvalidText(String field, int max) {
    return '$field: texto no válido (máximo $max caracteres).';
  }

  @override
  String archiveInvalidInteger(String field, int min, int max) {
    return '$field: valor no válido ($min–$max).';
  }

  @override
  String archiveInvalidIdentifier(String field) {
    return '$field: identificador no válido.';
  }

  @override
  String archiveCsvExtraFields(int row) {
    return 'La fila $row tiene más campos que la cabecera.';
  }

  @override
  String archiveCsvInvalidSection(int row) {
    return 'Fila $row: el nombre de sección no es válido; sus tareas no tendrán lista.';
  }

  @override
  String archiveCsvListDescription(int row) {
    return 'Fila $row: las descripciones de lista no son compatibles.';
  }

  @override
  String archiveCsvOrphanComment(int row) {
    return 'Fila $row: el comentario no tiene una tarea válida anterior; se omitirá.';
  }

  @override
  String archiveCsvUnsupportedRow(int row) {
    return 'Fila $row: el tipo de registro no es compatible; se omitirá.';
  }

  @override
  String archiveCsvFieldInNotes(String field) {
    return '$field se conservará como texto en las notas.';
  }

  @override
  String archiveField(String field) {
    String _temp0 = intl.Intl.selectLogic(
      field,
      {
        'export_id': 'identificador de exportación',
        'tasks': 'tareas',
        'lists': 'listas',
        'list_id': 'identificador de lista',
        'list_name': 'nombre de lista',
        'task_identifier': 'identificador de tarea',
        'title': 'título',
        'notes': 'notas',
        'priority': 'prioridad',
        'duration': 'duración',
        'repeat_interval': 'intervalo de repetición',
        'repeat_weekdays': 'días de repetición',
        'weekday': 'día de la semana',
        'completed_dates': 'fechas completadas',
        'individual_date_changes': 'cambios de fecha individuales',
        'list_identifier': 'identificador de lista',
        'labels': 'etiquetas',
        'label': 'etiqueta',
        'checklist': 'lista de pasos',
        'checklist_identifier': 'identificador de paso',
        'checklist_title': 'título de paso',
        'checklist_dates': 'fechas de pasos',
        'reminder_lead': 'antelación del recordatorio',
        'reminder_time': 'hora del recordatorio',
        'other': 'campo',
      },
    );
    return '$_temp0';
  }
}
