// Runtime config. The Cognito values are filled from `terraform output`
// after apply (see scripts/write-frontend-config.ps1). Safe to commit —
// Cognito client IDs and pool IDs are public by design for SPA clients.
export const config = {
  region: "us-east-1",
  cognito: {
    userPoolId: "us-east-1_IU2sbEN3x",
    clientId: "3kmtug4kvilgqttbtb3hqepag4",
  },
};
