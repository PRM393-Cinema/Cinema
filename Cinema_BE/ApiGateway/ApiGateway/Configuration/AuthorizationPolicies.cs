namespace ApiGateway.Configuration
{
    // Tên policy dùng trong ReverseProxy:Routes:*:AuthorizationPolicy.
    // Ngoài ra YARP có sẵn "anonymous" (không cần token) và "default" (chỉ cần đăng nhập).
    public static class AuthorizationPolicies
    {
        public const string AdminOnly = "AdminOnly";

        public const string StaffOrAdmin = "StaffOrAdmin";
    }
}
