namespace MovieService.Chat;

public sealed class ChatOptions
{
    public string ApiKey { get; set; } = "";
    public string Model { get; set; } = "openai/gpt-6.1-sol";
    public string ReasoningEffort { get; set; } = "medium";
}
