using DevExpress.ExpressApp.ApplicationBuilder;
using DevExpress.ExpressApp.Blazor.ApplicationBuilder;
using DevExpress.ExpressApp.Blazor.Services;
using DevExpress.Persistent.Base;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Components.Server.Circuits;
using Microsoft.EntityFrameworkCore;
using XAFDocker.Blazor.Server.Services;

namespace XAFDocker.Blazor.Server
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        // For more information on how to configure your application, visit https://go.microsoft.com/fwlink/?LinkID=398940
        public void ConfigureServices(IServiceCollection services)
        {
            services.AddSingleton(typeof(Microsoft.AspNetCore.SignalR.HubConnectionHandler<>), typeof(ProxyHubConnectionHandler<>));

            services.AddRazorPages();
            services.AddServerSideBlazor();
            services.AddHttpContextAccessor();
            services.AddScoped<CircuitHandler, CircuitHandlerProxy>();

            // Add health checks for container monitoring
            services.AddHealthChecks();
            services.AddXaf(Configuration, builder =>
            {
                builder.UseApplication<XAFDockerBlazorApplication>();
                builder.Modules
                    .AddConditionalAppearance()
                    .AddValidation(options =>
                    {
                        options.AllowValidationDetailsAccess = false;
                    })
                    .Add<XAFDocker.Module.XAFDockerModule>()
                    .Add<XAFDockerBlazorModule>();
                builder.ObjectSpaceProviders
                    .AddEFCore(options =>
                    {
                        options.PreFetchReferenceProperties();
                    })
                    .WithDbContext<XAFDocker.Module.BusinessObjects.XAFDockerEFCoreDbContext>((serviceProvider, options) =>
                    {
                        // Get connection string from configuration
                        // In Docker/Production: Environment variables from docker-compose.yml override appsettings.Production.json
                        // In Development: Uses appsettings.Development.json or appsettings.json (LocalDB)
                        string connectionString = null;

#if EASYTEST
                        if(Configuration.GetConnectionString("EasyTestConnectionString") != null) {
                            connectionString = Configuration.GetConnectionString("EasyTestConnectionString");
                        }
#endif
                        if (connectionString == null && Configuration.GetConnectionString("ConnectionString") != null)
                        {
                            connectionString = Configuration.GetConnectionString("ConnectionString");
                        }

                        ArgumentNullException.ThrowIfNull(connectionString);

                        options.UseSqlServer(connectionString);
                        options.UseChangeTrackingProxies();
                        options.UseObjectSpaceLinkProxies();
                    })
                    .AddNonPersistent();
            });
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Error");
                // The default HSTS value is 30 days. To change this for production scenarios, see: https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }
            // In production/Docker, HTTPS is handled by nginx reverse proxy
            // Only use HTTPS redirection in development
            if (env.IsDevelopment())
            {
                app.UseHttpsRedirection();
            }

            app.UseRequestLocalization();
            app.UseStaticFiles();
            app.UseRouting();
            app.UseXaf();
            app.UseEndpoints(endpoints =>
            {
                // Health check endpoint for Docker container monitoring
                endpoints.MapHealthChecks("/health");

                endpoints.MapXafEndpoints();
                endpoints.MapBlazorHub();
                endpoints.MapFallbackToPage("/_Host");
                endpoints.MapControllers();
            });
        }
    }
}
