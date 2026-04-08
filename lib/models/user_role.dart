enum UserRole { admin, floorLeader, resident }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.floorLeader:
        return 'Floor Leader';
      case UserRole.resident:
        return 'Resident';
    }
  }
}

/// =============================================================
/// RESIDENT STATUS
/// =============================================================

enum ResidentStatus { active, inactive, pending }

/// =============================================================
/// INVENTORY CATEGORY
/// =============================================================

enum InventoryCategory { cleaning, equipment, furniture, electronics, other }
