using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace TransportManagement.IntegrationTests;

internal static class OperationsTestClient
{
    public static async Task<HttpClient> AuthenticatedClientAsync(
        ApiFactory factory,
        string email,
        string password = ApiFactory.Password)
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/auth/login", new
        {
            email,
            password
        }, cancellationToken);
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", body.GetProperty("accessToken").GetString());
        return client;
    }

    public static async Task<JsonElement> RequiredJsonAsync(
        this HttpResponseMessage response)
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken);
    }

    public static Task<HttpResponseMessage> PostJsonAsync<T>(this HttpClient client, string path, T value) =>
        client.PostAsJsonAsync(path, value, TestContext.Current.CancellationToken);

    public static Task<HttpResponseMessage> PutJsonAsync<T>(this HttpClient client, string path, T value) =>
        client.PutAsJsonAsync(path, value, TestContext.Current.CancellationToken);

    public static Task<T?> GetJsonAsync<T>(this HttpClient client, string path) =>
        client.GetFromJsonAsync<T>(path, TestContext.Current.CancellationToken);

    public static Task<HttpResponseMessage> GetResponseAsync(this HttpClient client, string path) =>
        client.GetAsync(path, TestContext.Current.CancellationToken);

    public static Task<HttpResponseMessage> PostEmptyAsync(this HttpClient client, string path) =>
        client.PostAsync(path, null, TestContext.Current.CancellationToken);
}
