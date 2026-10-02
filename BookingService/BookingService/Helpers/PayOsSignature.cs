using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace BookingService.Helpers
{
    // Chữ ký webhook PayOS (https://payos.vn/docs/tich-hop-webhook/kiem-tra-du-lieu-voi-signature/):
    // các field của "data" sắp theo tên a-z, nối "key=value" bằng "&" (null -> rỗng, mảng -> JSON đã sắp key),
    // rồi HMAC-SHA256 với checksum key, kết quả dạng hex.
    public static class PayOsSignature
    {
        private static readonly JsonWriterOptions JsonOptions = new()
        {
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
        };

        public static string Create(JsonElement data, string checksumKey)
        {
            var payload = string.Join(
                "&",
                data.EnumerateObject()
                    .OrderBy(property => property.Name, StringComparer.Ordinal)
                    .Select(property => $"{property.Name}={ToValue(property.Value)}"));

            using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(checksumKey));

            return Convert.ToHexString(
                    hmac.ComputeHash(Encoding.UTF8.GetBytes(payload)))
                .ToLowerInvariant();
        }

        // body = toàn bộ JSON PayOS gửi tới: { code, desc, success, data: {...}, signature }
        public static bool IsValid(JsonElement body, string checksumKey)
        {
            if (string.IsNullOrEmpty(checksumKey) ||
                body.ValueKind != JsonValueKind.Object ||
                !body.TryGetProperty("data", out var data) ||
                data.ValueKind != JsonValueKind.Object ||
                !body.TryGetProperty("signature", out var signature) ||
                signature.ValueKind != JsonValueKind.String)
            {
                return false;
            }

            var expected = Encoding.ASCII.GetBytes(Create(data, checksumKey));
            var actual = Encoding.ASCII.GetBytes(
                signature.GetString()!.Trim().ToLowerInvariant());

            return CryptographicOperations.FixedTimeEquals(expected, actual);
        }

        private static string ToValue(JsonElement value)
        {
            switch (value.ValueKind)
            {
                case JsonValueKind.Null:
                case JsonValueKind.Undefined:
                    return string.Empty;
                case JsonValueKind.String:
                    var text = value.GetString()!;
                    return text is "null" or "undefined" ? string.Empty : text;
                case JsonValueKind.True:
                    return "true";
                case JsonValueKind.False:
                    return "false";
                case JsonValueKind.Number:
                    return value.GetRawText();
                default:
                    return ToSortedJson(value);
            }
        }

        // Giống JSON.stringify của SDK PayOS: object trong mảng được sắp key, không thêm khoảng trắng
        private static string ToSortedJson(JsonElement value)
        {
            using var stream = new MemoryStream();

            using (var writer = new Utf8JsonWriter(stream, JsonOptions))
            {
                WriteSorted(writer, value);
            }

            return Encoding.UTF8.GetString(stream.ToArray());
        }

        private static void WriteSorted(Utf8JsonWriter writer, JsonElement value)
        {
            switch (value.ValueKind)
            {
                case JsonValueKind.Object:
                    writer.WriteStartObject();
                    foreach (var property in value.EnumerateObject()
                                 .OrderBy(property => property.Name, StringComparer.Ordinal))
                    {
                        writer.WritePropertyName(property.Name);
                        WriteSorted(writer, property.Value);
                    }
                    writer.WriteEndObject();
                    break;
                case JsonValueKind.Array:
                    writer.WriteStartArray();
                    foreach (var item in value.EnumerateArray())
                    {
                        WriteSorted(writer, item);
                    }
                    writer.WriteEndArray();
                    break;
                default:
                    value.WriteTo(writer);
                    break;
            }
        }
    }
}
