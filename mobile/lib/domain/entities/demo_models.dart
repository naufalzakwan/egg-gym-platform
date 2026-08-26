enum TaskStatus { done, inProgress, todo }

class ProjectTask {
  const ProjectTask({
    required this.title,
    required this.description,
    required this.status,
    required this.scope,
  });

  final String title;
  final String description;
  final TaskStatus status;
  final String scope;
}

class MembershipPlan {
  const MembershipPlan({
    this.backendId,
    this.slug,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.periodLabel,
    this.priceValue,
    this.billingPeriod,
    this.durationDays,
    this.features = const [],
    this.badge,
    this.isHighlighted = false,
    this.isBestSeller = false,
  });

  final int? backendId;
  final String? slug;
  final String title;
  final String subtitle;
  final String priceLabel;
  final String periodLabel;
  final double? priceValue;
  final String? billingPeriod;
  final int? durationDays;
  final List<String> features;
  final String? badge;
  final bool isHighlighted;
  final bool isBestSeller;
}

class TrainerProfile {
  const TrainerProfile({
    this.backendId,
    required this.name,
    required this.specialty,
    required this.bio,
    required double rating,
    required int reviewsCount,
    this.tier,
    this.isAvailable = true,
    this.hasActiveSchedule = false,
    this.activeMembers = 0,
    this.maxMembers = 2,
    this.experienceYears,
    this.certifications = const [],
    this.servedClientsCount,
    this.pricePerSession,
    this.avatarUrl,
    this.displayPhotoPath,
    this.specialties = const [],
  })  : reviewsCount = reviewsCount > 0 &&
                rating > 0 &&
                rating <= 5 &&
                rating != double.infinity &&
                rating != double.negativeInfinity
            ? reviewsCount
            : 0,
        rating = reviewsCount > 0 &&
                rating > 0 &&
                rating <= 5 &&
                rating != double.infinity &&
                rating != double.negativeInfinity
            ? rating
            : 0;

  final int? backendId;
  final String name;
  final String specialty;
  final String bio;
  final double rating;
  final int reviewsCount;

  String get reviewsLabel =>
      '$reviewsCount ${reviewsCount == 1 ? 'review' : 'reviews'}';
  final String? tier;

  /// Apakah trainer masih punya kuota untuk menerima member baru.
  final bool isAvailable;

  /// Apakah trainer memiliki minimal satu jadwal booking aktif di backend.
  /// Nilai ini terpisah dari [isAvailable], yang hanya mewakili kuota member.
  final bool hasActiveSchedule;

  /// Jumlah member aktif yang sedang ditangani trainer ini (kuota).
  final int activeMembers;

  /// Kuota maksimal member aktif per trainer.
  final int maxMembers;

  /// Lama pengalaman (tahun) dari backend `experience_years`. Null bila kosong.
  final int? experienceYears;

  /// Sertifikasi real dari backend `certifications_list`. Parser public tetap
  /// mendukung string comma-separated lama sebagai fallback kompatibilitas.
  final List<String> certifications;

  /// Jumlah member unik yang sudah/sedang dilayani (backend
  /// `served_clients_count`): DISTINCT member dari booking completed/confirmed
  /// UNION member yang sudah memberi rating. Beda dari [activeMembers] (kuota).
  final int? servedClientsCount;
  final double? pricePerSession;
  final String? avatarUrl;
  final String? displayPhotoPath;
  final List<String> specialties;

  List<String> get specialtyLabels =>
      specialties.isNotEmpty ? specialties : [specialty];

  int get certificationCount => certifications.length;
}

class EquipmentInfo {
  const EquipmentInfo({
    this.id,
    this.code,
    required this.name,
    required this.category,
    required this.description,
    required this.focus,
    this.status = 'available',
    this.statusLabel = 'Tersedia',
    this.imagePath,
    this.stageLabel,
    this.usageWindow,
    this.bestFor,
    this.difficulty,
    this.keyBenefits = const <String>[],
    this.usageFlow = const <String>[],
    this.safetyNotes = const <String>[],
    this.suggestedMovements = const <String>[],
    this.movements = const <GymEquipmentMovement>[],
    this.isActive = true,
  });

  final int? id;
  final String? code;
  final String name;
  final String category;
  final String description;
  final String focus;
  final String status;
  final String statusLabel;
  final String? imagePath;
  final String? stageLabel;
  final String? usageWindow;
  final String? bestFor;
  final String? difficulty;
  final List<String> keyBenefits;
  final List<String> usageFlow;
  final List<String> safetyNotes;
  final List<String> suggestedMovements;
  final List<GymEquipmentMovement> movements;
  final bool isActive;

  bool get isAvailable => status == 'available';
}

class GymEquipmentMovement {
  const GymEquipmentMovement({
    required this.id,
    required this.movementName,
    required this.targetArea,
    required this.sortOrder,
  });

  final int id;
  final String movementName;
  final String targetArea;
  final int sortOrder;
}

class WorkoutSession {
  const WorkoutSession({
    required this.title,
    required this.focus,
    required this.progressText,
    required this.statusLabel,
    this.isLocked = false,
    this.isComplete = false,
  });

  final String title;
  final String focus;
  final String progressText;
  final String statusLabel;
  final bool isLocked;
  final bool isComplete;
}

class ScheduleSession {
  const ScheduleSession({
    this.backendId,
    this.bookingNumber,
    this.createdAt,
    this.memberProfileId,
    this.trainerProfileId,
    this.trainerAvatarUrl,
    this.trainerDisplayPhotoPath,
    required this.clientName,
    required this.timeRange,
    required this.location,
    required this.status,
    required this.note,
    this.sessionDate,
    this.paymentProofUrl,
    this.paymentVerifiedAt,
    this.sessionCount = 1,
    this.rawStatus,
    this.hasProgram = false,
    this.trainingProgramId,
    this.activeProgramSessionId,
    this.activeProgramSessionTitle,
    this.activeProgramSessionMemberReady = false,
    this.activeProgramSessionReservationId,
    this.executionBlockedByPendingReschedule = false,
    this.sessionTitle,
    this.memberNote,
    this.memberGender,
    this.memberBirthDate,
    this.memberHeightCm,
    this.memberWeightKg,
    this.memberFitnessGoal,
    this.memberMedicalNote,
    this.memberTier,
    this.memberEmail,
    this.memberPhone,
    this.memberCode,
    this.memberAvatarUrl,
    this.activeMembership,
    this.programCompleted = false,
    this.pricePerSession,
    this.totalAmount,
    this.reservations = const [],
    this.expiredAt,
    this.remainingSeconds = 0,
    this.expiryStage,
    this.isExpired = false,
    this.isPaymentVerificationOverdue = false,
    this.paymentVerificationOverdueSeconds = 0,
  });

  final int? backendId;
  final String? bookingNumber;
  final DateTime? createdAt;
  final int? memberProfileId;
  final int? trainerProfileId;
  final String? trainerAvatarUrl;
  final String? trainerDisplayPhotoPath;
  final String clientName;
  final String timeRange;
  final String location;
  final String status;
  final String note;
  final String? sessionDate;
  final String? paymentProofUrl;
  final DateTime? paymentVerifiedAt;
  final int sessionCount;

  /// Status mentah dari backend (pending, waiting_payment, payment_uploaded,
  /// payment_verified, confirmed, rescheduled, cancelled). Dipakai untuk
  /// menentukan tombol aksi di sisi trainer.
  final String? rawStatus;

  /// Apakah trainer sudah membuat program latihan (punya sesi) untuk sesi ini.
  final bool hasProgram;

  /// ID program latihan aktif untuk engagement ini (jika sudah dibuat).
  /// Dipakai untuk shortcut "Mulai Sesi" ke halaman kontrol progres.
  final int? trainingProgramId;
  final int? activeProgramSessionId;
  final String? activeProgramSessionTitle;
  final bool activeProgramSessionMemberReady;
  final int? activeProgramSessionReservationId;
  final bool executionBlockedByPendingReschedule;

  /// Judul sesi yang diisi member saat mengajukan booking.
  final String? sessionTitle;

  /// Catatan/fokus latihan yang diisi member di form booking.
  final String? memberNote;

  // Data profil fisik member (bahan pertimbangan trainer sebelum konfirmasi).
  final String? memberGender;
  final String? memberBirthDate;
  final double? memberHeightCm;
  final double? memberWeightKg;
  final String? memberFitnessGoal;
  final String? memberMedicalNote;

  /// Tier membership member yang sedang aktif (untuk badge di detail booking).
  final String? memberTier;
  final String? memberEmail;
  final String? memberPhone;
  final String? memberCode;
  final String? memberAvatarUrl;
  final ScheduleSessionActiveMembership? activeMembership;

  /// Apakah program latihan untuk sesi ini sudah 100% selesai (semua sesi
  /// completed). Dipakai menampilkan status "PROGRAM SELESAI" di card Home.
  final bool programCompleted;
  final double? pricePerSession;
  final double? totalAmount;
  final List<BookingSessionReservation> reservations;
  final DateTime? expiredAt;
  final int remainingSeconds;
  final String? expiryStage;
  final bool isExpired;
  final bool isPaymentVerificationOverdue;
  final int paymentVerificationOverdueSeconds;
}

class ScheduleSessionActiveMembership {
  const ScheduleSessionActiveMembership({
    this.planName,
    this.startDate,
    this.endDate,
    this.status,
    this.paymentStatus,
  });

  final String? planName;
  final String? startDate;
  final String? endDate;
  final String? status;
  final String? paymentStatus;
}

class BookingSessionReservation {
  const BookingSessionReservation({
    this.id,
    required this.sequenceOrder,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.activeRescheduleRequest,
  });

  final int? id;
  final int sequenceOrder;
  final String sessionDate;
  final String startTime;
  final String endTime;
  final String status;
  final BookingRescheduleRequestData? activeRescheduleRequest;
}

class BookingRescheduleRequestData {
  const BookingRescheduleRequestData({
    required this.id,
    required this.bookingId,
    required this.reservationId,
    required this.requestedByRole,
    required this.requestedByName,
    required this.status,
    required this.oldDate,
    required this.oldStartTime,
    required this.oldEndTime,
    required this.proposedDate,
    required this.proposedStartTime,
    required this.proposedEndTime,
    required this.reasonType,
    this.reasonNote,
    this.expiredAt,
    this.isIncoming = false,
    this.canAccept = false,
    this.canReject = false,
    this.canCancel = false,
    this.rejectedReasonType,
    this.rejectedReasonNote,
  });

  final int id;
  final int bookingId;
  final int reservationId;
  final String requestedByRole;
  final String requestedByName;
  final String status;
  final String oldDate;
  final String oldStartTime;
  final String oldEndTime;
  final String proposedDate;
  final String proposedStartTime;
  final String proposedEndTime;
  final String reasonType;
  final String? reasonNote;
  final DateTime? expiredAt;
  final bool isIncoming;
  final bool canAccept;
  final bool canReject;
  final bool canCancel;
  final String? rejectedReasonType;
  final String? rejectedReasonNote;
}

class TransactionItem {
  const TransactionItem({
    required this.title,
    required this.amount,
    required this.dateLabel,
    required this.status,
  });

  final String title;
  final String amount;
  final String dateLabel;
  final String status;
}

class PhysicalProgressEntry {
  const PhysicalProgressEntry({
    required this.id,
    required this.recordedDateLabel,
    required this.weightKg,
    required this.heightCm,
    required this.note,
    required this.photoLabel,
    required this.stageLabel,
    this.isMilestone = false,
  });

  final int id;
  final String recordedDateLabel;
  final double weightKg;
  final double heightCm;
  final String note;
  final String photoLabel;
  final String stageLabel;
  final bool isMilestone;
}

class ClientSummary {
  const ClientSummary({
    this.backendId,
    this.memberCode,
    required this.name,
    required this.goal,
    required this.progressLabel,
    required this.nextSession,
    this.avatarUrl,
    this.heightCm,
    this.weightKg,
    this.medicalNote,
  });

  final int? backendId;
  final String? memberCode;
  final String name;
  final String goal;
  final String progressLabel;
  final String nextSession;

  /// Relative path avatar member (mis. "avatars/x.jpg") dari backend. Dirender
  /// via InitialAvatar(avatarPath:) -> baseUrl dinamis; null -> fallback inisial.
  final String? avatarUrl;
  final double? heightCm;
  final double? weightKg;
  final String? medicalNote;
}

class TrainerDraftExercise {
  const TrainerDraftExercise({
    required this.name,
    required this.targetMuscle,
    required this.sets,
    required this.reps,
    this.equipmentId,
    this.equipmentName,
    this.equipmentMovementId,
  });

  final String name;
  final String targetMuscle;
  final int sets;
  final int reps;
  final int? equipmentId;
  final String? equipmentName;
  final int? equipmentMovementId;

  TrainerDraftExercise copyWith({
    String? name,
    String? targetMuscle,
    int? sets,
    int? reps,
    int? equipmentId,
    String? equipmentName,
    int? equipmentMovementId,
  }) {
    return TrainerDraftExercise(
      name: name ?? this.name,
      targetMuscle: targetMuscle ?? this.targetMuscle,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      equipmentMovementId: equipmentMovementId ?? this.equipmentMovementId,
    );
  }
}

class TrainerDraftSession {
  const TrainerDraftSession({
    required this.title,
    required this.focus,
    required this.totalExercises,
    required this.durationMinutes,
    required this.exercises,
  });

  final String title;
  final String focus;
  final int totalExercises;
  final int durationMinutes;
  final List<TrainerDraftExercise> exercises;

  TrainerDraftSession copyWith({
    String? title,
    String? focus,
    int? totalExercises,
    int? durationMinutes,
    List<TrainerDraftExercise>? exercises,
  }) {
    return TrainerDraftSession(
      title: title ?? this.title,
      focus: focus ?? this.focus,
      totalExercises: totalExercises ?? this.totalExercises,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      exercises: exercises ?? this.exercises,
    );
  }
}

class TrainerSyncedExerciseProgress {
  const TrainerSyncedExerciseProgress({
    required this.order,
    required this.title,
    required this.subtitle,
    required this.cue,
    required this.totalSets,
    required this.completedSets,
  });

  final int order;
  final String title;
  final String subtitle;
  final String cue;
  final int totalSets;
  final int completedSets;

  bool get isComplete => completedSets >= totalSets;
}

class OperationHour {
  const OperationHour({
    required this.day,
    required this.hours,
  });

  final String day;
  final String hours;
}

class MemberDashboardData {
  const MemberDashboardData({
    required this.memberName,
    required this.currentTier,
    required this.packageName,
    required this.validUntil,
    required this.remainingDays,
    required this.nextSession,
    required this.programSessions,
    required this.recentTransactions,
  });

  final String memberName;
  final String currentTier;
  final String packageName;
  final String validUntil;
  final int remainingDays;
  final ScheduleSession nextSession;
  final List<WorkoutSession> programSessions;
  final List<TransactionItem> recentTransactions;
}

class GuestShowcaseData {
  const GuestShowcaseData({
    required this.plans,
    required this.trainers,
    required this.equipments,
    required this.operationHours,
  });

  final List<MembershipPlan> plans;
  final List<TrainerProfile> trainers;
  final List<EquipmentInfo> equipments;
  final List<OperationHour> operationHours;
}

class TrainerDashboardData {
  const TrainerDashboardData({
    required this.trainerName,
    required this.activeClients,
    required this.todaySessions,
    required this.rating,
    required this.todayAgenda,
    required this.clients,
    required this.programSessions,
  });

  final String trainerName;
  final int activeClients;
  final int todaySessions;
  final double rating;
  final List<ScheduleSession> todayAgenda;
  final List<ClientSummary> clients;
  final List<WorkoutSession> programSessions;
}
