# Copilot Agent Responses

- Keep answers concise, direct, and free of filler
- Avoid unnecessary explanations or repetition
- Prefer bullet points or code blocks over long prose
- Code responses: return only the requested code block, no extra text
- Limit responses to max 10 lines or 500 characters, excluding code blocks
- If output exceeds the limit, split into multiple concise responses

---

# Coding standards

- Target .NET 9 for all projects
- Follow the project's `.editorconfig` settings strictly for formatting, style, and language features
- Respect .NET and C# version constraints—use only available language features and APIs
- Dispose resources properly, preferably with `using` statements
- Avoid unnecessary allocations in hot paths
- Place one class per file; filename matches class name
- For methods with four or more parameters, create a custom POCO arguments class
- For long method signatures or class declarations, split parameters or interfaces across multiple lines
- Use primary constructors with `readonly` fields when appropriate
- Avoid methods longer than 50 lines
- Avoid classes with more than 10 dependencies
- Avoid deep nesting (more than 3-4 levels)
- Avoid complex conditional logic; use Strategy pattern or rules engine if needed
- Avoid hardcoded values; use configuration or constants
- Do not add XML documentation unless code is genuinely complex
- Add `TODO` comments for missing implementation (`// TODO: [Ticket] Description`)
- Explain non-obvious optimizations or complex code with inline comments
- Use `record` classes for immutable data structures
- Use `record class` for mutable records
- Use `class` for complex objects with behavior
- Seal classes by default unless designed for inheritance
- Add a `Base` suffix to abstract classes
- Prefer arrow methods (`=>`) for simple logic or LINQ chains returning data
- Always place the arrow (`=>`) on a new line for readability
- Always create interface/implementation pairs for services, clients, maps, processing units

---

# Naming conventions

## General

- **PascalCase**: Use for classes, methods, properties, enums, namespaces, and constants (no underscore).
- **camelCase**: Use for parameters, local variables, and local constants.
- **\_camelCase**: Use for private fields, prefixed with an underscore.
- **IPascalCase**: Use for interfaces, with an 'I' prefix (e.g., `IUserService`).

## Type Suffixes

- **Clients (external integrations: HTTP, SQL, etc.)**: Use the resource name with `Client` suffix (`IOrderClient`, `OrderClient`)
- **Services (business logic, orchestration)**: Use the resource name with `Service` suffix (`IUserService`, `UserService`)
- **Mapping classes**: Use the resource name with `Map` suffix (`IUserMap`, `UserMap`)

## Endpoint and Model Naming Patterns

- **Endpoints**: `{Action}{Resource}Endpoint` (E.g. `GetUsersEndpoint`, `UpdateProfileEndpoint`)
- **Services**: `{FeatureName}Service` (E.g. `PaymentService`, `NotificationService`)
- **Clients**: `{FeatureName}Client` (E.g. `PaymentClient`, `TranslationClient`)
- **Models**: `{Action}{Resource}{Purpose}` (E.g. `CreateOrderRequest`, `GetUsersResponse`, `GetUsersResponseUser`)

---

# Folder structure

- Use a `Features` folder to organize code by business functionality
- Group related classes inside feature folders with descriptive names
- Use action-based naming for endpoints: `{Action}{Resource}Endpoint` (e.g., `CreateUserEndpoint`)
- Use the feature name for services and clients (e.g., `PaymentService`, `TranslationClient`)
- Use `Request` and `Response` suffixes for models
- Prefix classes with the feature name for clarity (e.g., `GetUsersEndpoint`, `CreateOrderRequest`)
- Keep related classes together (endpoint, request, response models)
- Create subfolders for logical groupings only when many classes exist (e.g., `Response`, `Options`, `Validators`)
- When using subfolders, keep full feature context in class names (e.g., `GetUsersResponse`, `GetUsersResponseUser`)

## Examples

### Basic feature structure

```
Features/
├── GetUsers/
│   ├── GetUsersEndpoint.cs
│   ├── GetUsersRequest.cs
│   └── GetUsersResponse.cs
├── CreateOrder/
│   ├── CreateOrderEndpoint.cs
│   ├── CreateOrderRequest.cs
│   ├── CreateOrderRequestValidator.cs
│   ├── CreateOrderResponse.cs
│   └── CreateOrderService.cs
```

### Feature with many models

```
Features/
├── PaymentProcessing/
│   ├── IPaymentProcessingClient.cs
│   ├── PaymentProcessingClient.cs
│   ├── PaymentProcessingRequest.cs
│   ├── PaymentProcessingResponse.cs
│   ├── PaymentProcessingOptions.cs
│   ├── PaymentProcessingOptionsConfigure.cs
│   └── Response/
│       ├── PaymentProcessingResponseUser.cs
│       ├── PaymentProcessingResponseBank.cs
│       └── PaymentProcessingResponseCard.cs
```

---

# Null safety and property access

- Use null-coalescing operator (`??`) wisely and only where needed
- For repeated nested property access, assign to a local variable for readability and performance
- Prefer explicit null checks (`is null`) over excessive null-coalescing
- Use the `is` operator for pattern matching against `null`, constants, and combined patterns
- Use `or`, `and`, and `{}` property patterns for cleaner conditional logic

---

# String comparison

- Always use `string.Equals()` for string comparisons instead of `==`
- Use `StringComparison.OrdinalIgnoreCase` by default unless culture-specific comparison is needed
- Use `StringComparer.OrdinalIgnoreCase` for collections, dictionaries, LINQ
- Be explicit about string comparison to avoid culture-related bugs

---

# Dates

## Instructions

- Prefer `TimeProvider` over static `DateTime.Now`/`DateTimeOffset.Now` for testability and dependency injection
- Prefer `DateTimeOffset` over `DateTime` for all date/time operations
- When forced to use `DateTime`, add a `Utc` suffix and convert to UTC early
- When constructing `DateTime` or `DateTimeOffset`, always specify `DateTimeKind` or `TimeSpan` offset

---

# Collections

- Use arrays (`T[]`) for fixed-size collections
- Use `List<T>` for adding/removing items
- For dictionaries:
  - Use `Dictionary<TKey, TValue>` for mutable dictionaries.
  - Use `ReadOnlyDictionary<TKey, TValue>` for read-only access.
  - Use `IReadOnlyDictionary<TKey, TValue>` for interface return types.
  - Use `ConcurrentDictionary<TKey, TValue>` only when thread-safety is required.
- For other thread-safe collections (`ConcurrentBag<T>`, `ConcurrentQueue<T>`, `ConcurrentStack<T>`), use them only when necessary. Prefer regular collections with proper synchronization.
- For interface return types, use the least privileged type:
  - `IEnumerable<T>` for iteration only.
  - `ICollection<T>` when count/add/remove is needed.
  - `IList<T>` when indexed access is needed.
  - `IReadOnlyList<T>` for read-only indexed access.
  - `IReadOnlyDictionary<TKey, TValue>` for read-only dictionary access.
- Always materialize query results before returning (`.ToArray()`, `.ToList()`, `.ToDictionary()`)
- Never return raw enumerable queries (e.g., LINQ expressions)
- Always initialize collections to an empty state. Use the null-coalescing operator (`?? []`) wisely at the end of a chain.
- If the `[]` literal is unavailable in your target C# version, use alternatives like `Enumerable.Empty<T>()` or `Array.Empty<T>()`.
- Use `ReadOnlySpan<T>` and `Memory<T>` for performance-critical scenarios.

---

# Linq

- Break each LINQ chain to a new line for readability
- For multiple conditions in operators, place each condition on a new line with proper indentation
- Place operators at the start of the line, not the end
- Place null-conditional (`?`) and null-forgiving (`!`) operators at the end of the line they apply to
- Use the null-coalescing operator (`??`) wisely, typically only at the end of a chain
- For repeated nested property access, assign to a local variable first
- Use descriptive parameter names in lambda expressions

---

# Dependency injection

- Register services in `Program.cs` or dedicated extension methods
- Use appropriate lifetimes: `Singleton` for stateless, `Scoped` for per-request
- Prefer constructor injection over service locator
- Use `IServiceScopeFactory` to create scoped services within singletons
- Use `TryAdd*` methods (`TryAddScoped`, etc.) to prevent duplicate registrations
- For features with multiple services, create a dedicated `DependencyInjection.cs` extension class inside the feature folder

---

# Options pattern

- Use the options pattern for configuration management
- Define a POCO class for options, typically a `record`
- Create a class implementing `IConfigureOptions<T>` to bind config from a section
- Register options config using `services.ConfigureOptions<T>()`
- Inject `IOptions<T>` into services to access strongly-typed configuration values

---

# Result pattern

- If using the Result pattern, return appropriate error types instead of exceptions for expected failures
- Use project-specific error types (`Result.Fail()`, `Result.Error()`, or custom `Error`)
- Be consistent with error handling patterns in the codebase

---

# Argument Validation

- Always validate method arguments using the most appropriate exception type
- Choose the best exception for each case
- If the project uses the Result pattern, return an error instead of throwing for validation failures
- Prefer modern C# helpers like `ArgumentNullException.ThrowIfNull()`, `ArgumentException.ThrowIfNullOrWhiteSpace()`
- Common exceptions: `ArgumentNullException`, `ArgumentException`, `ArgumentOutOfRangeException`, `InvalidOperationException`

---

# Async and await

- Always use `ConfigureAwait(false)` in library code (not needed in ASP.NET Core controller actions)
- Prefer `Task<T>` over `Task<T?>` when null is not a valid outcome
- Use `ValueTask<T>` for high-frequency, possibly synchronous methods
- Always pass a `CancellationToken` through async calls to support cancellation
- Avoid `async void` methods—they can crash the process if an unhandled exception occurs
- Avoid blocking on async code with `.Result` or `.GetAwaiter().GetResult()`—this can cause deadlocks
- If forced to run an async method synchronously, use `.GetAwaiter().GetResult()` as a last resort and understand the risks

---

# Try-Catch

- Use `try-catch` only for ungraceful scenarios (external integrations: HTTP, DB, file system)
- Place `try-catch` blocks close to the integration point (e.g., around `httpClient.SendAsync()` or `sqlCommand.ExecuteAsync()`).
- When catching, return a neutral value like `null` or an empty collection
- Always log exceptions with context before handling
- If using the Result pattern, return an error `Result` instead of throwing
- Let exceptions bubble up for unexpected failures

---

# Data access

- When using EF Core, interact with `DbSet`s directly
- Avoid repository abstractions over EF Core
- For read-only operations, use `AsNoTracking()` for performance
- Use projections (`Select`) to query only necessary columns
- For simple data access without EF Core, use Dapper
- Choose the approach based on project complexity and performance needs

---

# Caching

- Use appropriate cache for each scenario (in-memory for single-instance, Redis for distributed)
- Create a static `CacheKeys` class for key generation/management
- Use meaningful cache key prefixes for organization/debugging
- Always handle cache misses gracefully
- Use appropriate expiration policies

### Service caching decorate pattern

```csharp
// 1. Interface
public interface IUserService
{
    Task<Result<User>> GetUserAsync(
        string userId,
        CancellationToken cancellationToken = default
    );
}

// 2. Implementation
public sealed class UserService(IDbContext context)
    : IUserService
{
    public async Task<Result<User>> GetUserAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        // Fetch from database
    }
}

// 3. Cache Decorator
public sealed class CachedUserService(
    IUserService userService,
    IDistributedCache cache
) : IUserService
{
    public async Task<Result<User>> GetUserAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var cacheKey = $"user:{userId}";
        var cached = await cache.GetStringAsync(cacheKey, cancellationToken);
        if (cached is not null)
        {
            return Result<User>.Ok(JsonSerializer.Deserialize<User>(cached)!);
        }

        var result = await userService.GetUserAsync(userId, cancellationToken);
        if (result.IsSuccess)
         {
            await cache.SetStringAsync(
                cacheKey,
                JsonSerializer.Serialize(result.Value),
                new DistributedCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(15)
                },
                cancellationToken);
        }

        return result;
    }
}

// 4. Decorate in DI (Dependency Injection)
public static class DependencyInjection
{
    public static IServiceCollection AddUserServices(this IServiceCollection services)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.TryAddScoped<UserService>();
        services.TryAddScoped<IUserService>(provider =>
            new CachedUserService(
                provider.GetRequiredService<UserService>(),
                provider.GetRequiredService<IDistributedCache>()
            )
        );

        return services;
    }
}
```

---

# Http client pattern

- Always use `IHttpClientFactory` for HTTP communication
- Register named/typed clients for different services
- Configure policies (retry, circuit breaker, timeout) as needed

---

# API Design

- Use kebab-case for all path segments (`/passenger-options`)
- Use plural nouns for top-level resources (`/users`, `/bookings`)
- Group by domain under `/api/{domain}`
- Use hierarchical nesting for subresources:
  - `/api/bookings/{id}/status`
  - `/api/bookings/{id}/passenger-details`
- Avoid verbs in paths (YES `/api/bookings/{id}/status`, NO `/api/getBookingStatus`)
- Use Microsoft API Versioning with path segment (`/api/v1/...`)
- Use HTTP verbs consistently: GET (list/single), POST (create), PUT (replace), PATCH (update), DELETE (remove)
- Return correct status codes (200, 201, 204, 400, 404, 409, 500)
- Use query params for filtering/sorting/pagination:
  - `/api/bookings?status=confirmed&page=2&pageSize=50`
  - `/api/flights?status=scheduled,cancelled`
- Ensure consistency, avoid overfetching, support projections if needed

---

# API documentation

- Always add meaningful Swagger attributes to all API endpoints (Controllers, Minimal API, FastEndpoints)
- Use `Produces` attribute with all possible status codes and DTOs
- Include `Summary` and `Description` for clarity
- Document all parameters with appropriate attributes (`FromRoute`, `FromQuery`, `FromBody`)
- Use OpenAPI `Tags` for grouping
- Use predefined constants instead of hardcoded values:
  - `MediaTypeNames` for content types (`MediaTypeNames.Application.Json`).
  - `HeaderNames` for HTTP headers (`HeaderNames.Accept`).
  - `StatusCodes` for ASP.NET Core status codes (`StatusCodes.Status200OK`).
  - `HttpStatusCode` for `System.Net` status codes.

---

# Unit testing

- Write tests for all new functionality
- Use the Arrange-Act-Assert pattern
- Name test methods: `MethodName_WhenCondition_ShouldExpectedBehavior`
- Limit each test method to a single assertion concept
- Always use `async Task` for async test methods
- Test all code branches, including every `if`, `switch`, `try-catch`, and conditional path
- Aim for over 90% code coverage
- Test for both success and failure scenarios
- Test edge cases and boundaries
- Create one test class per production class
- Use `[Theory]` with `[InlineData]` for parameterized tests
- When skipping tests, provide a meaningful reason: `[Fact(Skip = "Reason")]`
- Use project’s established test infrastructure if available; otherwise use raw xUnit, AutoFixture, NSubstitute
- Remain consistent with existing test patterns in the codebase
