using System.ComponentModel.DataAnnotations;

namespace MovieService.Chat;

public sealed class ChatRequest : IValidatableObject
{
    [Required, MinLength(1), MaxLength(12)]
    public List<ChatMessage> Messages { get; set; } = [];

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Messages is not { Count: > 0 }) yield break;
        for (var i = 0; i < Messages.Count; i++)
        {
            var message = Messages[i];
            if (message is null || message.Role != (i % 2 == 0 ? "user" : "assistant") ||
                string.IsNullOrWhiteSpace(message.Content))
            {
                yield return new ValidationResult("Messages must alternate user and assistant, starting with user.");
                yield break;
            }
        }
        if (Messages[^1].Role != "user")
            yield return new ValidationResult("The last message must be from the user.");
        if (Messages.Sum(message => message.Content.Length) > 12000)
            yield return new ValidationResult("The conversation is too long. Start a new chat.");
    }
}

public sealed record ChatMessage(
    [Required, RegularExpression("^(user|assistant)$")] string Role,
    [Required, StringLength(4000, MinimumLength = 1)] string Content);

public sealed record ChatReply(string Message);
