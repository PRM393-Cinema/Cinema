namespace MovieService.Configuration
{
    // Trùng tên và quyền với policy ở ApiGateway, để gọi thẳng vào service cũng bị chặn như khi đi qua gateway
    public static class AuthorizationPolicies
    {
        public const string AdminOnly = "AdminOnly";

        public const string StaffOrAdmin = "StaffOrAdmin";
    }
}
