namespace BookingService.Configuration
{
    public static class AuthorizationPolicies
    {
        public const string UserOrStaff = "UserOrStaff";

        public const string StaffOrAdmin = "StaffOrAdmin";

        public const string AnyRole = "AnyRole";
    }
}