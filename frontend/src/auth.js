// Cognito login via OIDC Authorization Code + PKCE (oidc-client-ts handles
// the redirect dance, PKCE, token storage, and refresh).
import { UserManager, WebStorageStateStore } from "oidc-client-ts";
import { config } from "./config";

const redirect = `${window.location.origin}/admin`;

export const userManager = new UserManager({
  authority: `https://cognito-idp.${config.region}.amazonaws.com/${config.cognito.userPoolId}`,
  client_id: config.cognito.clientId,
  redirect_uri: redirect,
  post_logout_redirect_uri: redirect,
  response_type: "code",
  scope: "openid email profile",
  userStore: new WebStorageStateStore({ store: window.localStorage }),
});

export const login = () => userManager.signinRedirect();
export const logout = () => userManager.signoutRedirect();
export const getUser = () => userManager.getUser();

// API Gateway's Cognito JWT authorizer checks the `aud` claim, which exists on
// the ID token (not the access token) — so we send the ID token as the bearer.
export async function getToken() {
  const user = await userManager.getUser();
  return user && !user.expired ? user.id_token : null;
}

// Call once on the /admin page to finish a redirect login if one is in flight.
export async function completeLoginIfRedirected() {
  if (window.location.search.includes("code=")) {
    await userManager.signinRedirectCallback();
    window.history.replaceState({}, "", "/admin"); // strip ?code=... from URL
  }
}
