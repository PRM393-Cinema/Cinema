// Account roles issued by AuthService.
const roleAdmin = 'ROLE_ADMIN';
const roleStaff = 'ROLE_STAFF';

// Staff and admin accounts run the cinema from the admin website.
bool isManagementAccount(List<String>? roles) =>
    roles != null && (roles.contains(roleAdmin) || roles.contains(roleStaff));

bool isAdminAccount(List<String>? roles) => roles?.contains(roleAdmin) ?? false;
