using System.Text.Json;
using BookingService.Helpers;

namespace BookingService.Tests.Unit;

public class PayOsSignatureTests
{
    // Ví dụ webhook trong tài liệu PayOS (checksum key mẫu của tài liệu)
    private const string DocChecksumKey = "1a54716c8f0efb2744fb28b6e38b25da7f67a925d98bc1c18bd8faaecadd7675";
    private const string DocSignature = "412e915d2871504ed31be63c8f62a149a4410d34c4c42affc9006ef9917eaa03";

    private const string DocData = """
        {
          "orderCode": 123,
          "amount": 3000,
          "description": "VQRIO123",
          "accountNumber": "12345678",
          "reference": "TF230204212323",
          "transactionDateTime": "2023-02-04 18:25:00",
          "currency": "VND",
          "paymentLinkId": "124c33293c43417ab7879e14c8d9eb18",
          "code": "00",
          "desc": "Thành công",
          "counterAccountBankId": "",
          "counterAccountBankName": "",
          "counterAccountName": null,
          "counterAccountNumber": "",
          "virtualAccountName": "",
          "virtualAccountNumber": ""
        }
        """;

    [Fact]
    public void Create_MatchesPayOsDocumentationExample()
    {
        var signature = PayOsSignature.Create(Parse(DocData), DocChecksumKey);

        Assert.Equal(DocSignature, signature);
    }

    [Fact]
    public void IsValid_AcceptsSignedWebhook_CaseInsensitive()
    {
        Assert.True(PayOsSignature.IsValid(Body(DocData, DocSignature), DocChecksumKey));
        Assert.True(PayOsSignature.IsValid(Body(DocData, DocSignature.ToUpperInvariant()), DocChecksumKey));
    }

    [Fact]
    public void IsValid_RejectsTamperedData()
    {
        var tampered = DocData.Replace("\"amount\": 3000", "\"amount\": 1");

        Assert.False(PayOsSignature.IsValid(Body(tampered, DocSignature), DocChecksumKey));
    }

    [Fact]
    public void IsValid_RejectsWrongKey()
    {
        Assert.False(PayOsSignature.IsValid(Body(DocData, DocSignature), "another-checksum-key"));
    }

    [Theory]
    [InlineData("""{ "code": "00", "data": { "orderCode": 1 } }""")]
    [InlineData("""{ "code": "00", "signature": "abc" }""")]
    [InlineData("""{ "data": "not-an-object", "signature": "abc" }""")]
    [InlineData("""[]""")]
    public void IsValid_RejectsMalformedBody(string json)
    {
        Assert.False(PayOsSignature.IsValid(Parse(json), DocChecksumKey));
    }

    [Fact]
    public void IsValid_RejectsWhenChecksumKeyIsMissing()
    {
        Assert.False(PayOsSignature.IsValid(Body(DocData, DocSignature), ""));
    }

    [Fact]
    public void Create_DoesNotDependOnFieldOrder()
    {
        var reordered = """{ "b": "2", "a": 1, "c": true }""";
        var ordered = """{ "a": 1, "b": "2", "c": true }""";

        Assert.Equal(
            PayOsSignature.Create(Parse(ordered), DocChecksumKey),
            PayOsSignature.Create(Parse(reordered), DocChecksumKey));
    }

    [Fact]
    public void Create_TreatsNullAndNullTextAsEmpty()
    {
        var empty = PayOsSignature.Create(Parse("""{ "a": "" }"""), DocChecksumKey);

        Assert.Equal(empty, PayOsSignature.Create(Parse("""{ "a": null }"""), DocChecksumKey));
        Assert.Equal(empty, PayOsSignature.Create(Parse("""{ "a": "null" }"""), DocChecksumKey));
        Assert.Equal(empty, PayOsSignature.Create(Parse("""{ "a": "undefined" }"""), DocChecksumKey));
    }

    private static JsonElement Parse(string json)
    {
        return JsonDocument.Parse(json).RootElement.Clone();
    }

    private static JsonElement Body(string data, string signature)
    {
        return Parse($$"""{ "code": "00", "desc": "success", "success": true, "data": {{data}}, "signature": "{{signature}}" }""");
    }
}
