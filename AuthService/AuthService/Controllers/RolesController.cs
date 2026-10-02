using AuthService.Service;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthService.Controllers
{
    [ApiController]
    [Route("api/v1/auth/roles")]
    [Authorize(Roles = "ROLE_ADMIN")]
    public class RolesController : ControllerBase
    {
        private readonly IUserManagementService _userManagementService;

        public RolesController(IUserManagementService userManagementService)
        {
            _userManagementService = userManagementService;
        }

        // GET /api/v1/auth/roles  -> ["ROLE_ADMIN", "ROLE_STAFF", "ROLE_CUSTOMER"]
        [HttpGet]
        public async Task<ActionResult<List<string>>> GetRoles()
        {
            return Ok(await _userManagementService.GetRolesAsync());
        }
    }
}
