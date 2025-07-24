// AWS Cognito Configuration - usando configuração dinâmica
const getCognitoConfig = () => {
    if (window.SISTEMA_RURAL_CONFIG) {
        return window.SISTEMA_RURAL_CONFIG.COGNITO;
    }
    
    // Fallback para desenvolvimento local
    return {
        region: 'us-east-1',
        userPoolId: 'us-east-1_EkIZzPSf0',
        clientId: '45c9vf0elept4c6l50cv7eo67q',
        domain: 'example-cloud-api-devops-auth.auth.us-east-1.amazoncognito.com'
    };
};

class CognitoAuth {
    constructor() {
        this.config = getCognitoConfig();
        this.accessToken = localStorage.getItem('accessToken');
        this.idToken = localStorage.getItem('idToken');
        this.refreshToken = localStorage.getItem('refreshToken');
        this.currentUsername = null;
        this.pendingConfirmationUsername = null;
    }

    // Google SSO
    signInWithGoogle() {
        const redirectUri = window.location.origin + '/callback.html';
        const url = `https://${this.config.domain}/oauth2/authorize?` +
            `client_id=${this.config.clientId}&` +
            `response_type=code&` +
            `scope=email+openid+profile&` +
            `redirect_uri=${encodeURIComponent(redirectUri)}&` +
            `identity_provider=Google&` +
            `prompt=select_account`;
        
        window.location.href = url;
    }

    // Exchange OAuth code for tokens
    async exchangeCodeForTokens(code) {
        const redirectUri = window.location.origin + '/callback.html';
        
        try {
            const response = await fetch(`https://${this.config.domain}/oauth2/token`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                },
                body: new URLSearchParams({
                    grant_type: 'authorization_code',
                    client_id: this.config.clientId,
                    code: code,
                    redirect_uri: redirectUri
                })
            });

            if (response.ok) {
                const data = await response.json();
                
                this.accessToken = data.access_token;
                this.idToken = data.id_token;
                this.refreshToken = data.refresh_token;
                
                localStorage.setItem('accessToken', this.accessToken);
                localStorage.setItem('idToken', this.idToken);
                localStorage.setItem('refreshToken', this.refreshToken);
                
                const payload = JSON.parse(atob(this.idToken.split('.')[1]));
                this.currentUsername = payload['cognito:username'] || payload.email || 'User';
                
                return { success: true };
            } else {
                throw new Error(`Token exchange failed: ${response.status}`);
            }
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    async signUp(username, password) {
        const url = `https://cognito-idp.${this.config.region}.amazonaws.com/`;
        
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-amz-json-1.1',
                'X-Amz-Target': 'AWSCognitoIdentityProviderService.SignUp'
            },
            body: JSON.stringify({
                ClientId: this.config.clientId,
                Username: username,
                Password: password,
                UserAttributes: [
                    {
                        Name: 'email',
                        Value: username
                    }
                ]
            })
        });

        const data = await response.json();
        
        if (data.UserSub) {
            this.pendingConfirmationUsername = username;
        }
        
        return data;
    }

    async confirmSignUp(username, confirmationCode) {
        const url = `https://cognito-idp.${this.config.region}.amazonaws.com/`;
        
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-amz-json-1.1',
                'X-Amz-Target': 'AWSCognitoIdentityProviderService.ConfirmSignUp'
            },
            body: JSON.stringify({
                ClientId: this.config.clientId,
                Username: username,
                ConfirmationCode: confirmationCode
            })
        });

        return await response.json();
    }

    async resendConfirmationCode(username) {
        const url = `https://cognito-idp.${this.config.region}.amazonaws.com/`;
        
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-amz-json-1.1',
                'X-Amz-Target': 'AWSCognitoIdentityProviderService.ResendConfirmationCode'
            },
            body: JSON.stringify({
                ClientId: this.config.clientId,
                Username: username
            })
        });

        return await response.json();
    }

    async signIn(username, password) {
        const url = `https://cognito-idp.${this.config.region}.amazonaws.com/`;
        this.currentUsername = username;
        
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-amz-json-1.1',
                'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth'
            },
            body: JSON.stringify({
                ClientId: this.config.clientId,
                AuthFlow: 'USER_PASSWORD_AUTH',
                AuthParameters: {
                    USERNAME: username,
                    PASSWORD: password
                }
            })
        });

        const data = await response.json();
        
        if (data.AuthenticationResult) {
            this.accessToken = data.AuthenticationResult.AccessToken;
            this.idToken = data.AuthenticationResult.IdToken;
            this.refreshToken = data.AuthenticationResult.RefreshToken;
            
            localStorage.setItem('accessToken', this.accessToken);
            localStorage.setItem('idToken', this.idToken);
            localStorage.setItem('refreshToken', this.refreshToken);
        }
        
        return data;
    }

    async respondToNewPasswordRequired(session, newPassword) {
        const url = `https://cognito-idp.${this.config.region}.amazonaws.com/`;
        
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-amz-json-1.1',
                'X-Amz-Target': 'AWSCognitoIdentityProviderService.RespondToAuthChallenge'
            },
            body: JSON.stringify({
                ClientId: this.config.clientId,
                ChallengeName: 'NEW_PASSWORD_REQUIRED',
                Session: session,
                ChallengeResponses: {
                    USERNAME: this.currentUsername,
                    NEW_PASSWORD: newPassword
                }
            })
        });

        const data = await response.json();
        
        if (data.AuthenticationResult) {
            this.accessToken = data.AuthenticationResult.AccessToken;
            this.idToken = data.AuthenticationResult.IdToken;
            this.refreshToken = data.AuthenticationResult.RefreshToken;
            
            localStorage.setItem('accessToken', this.accessToken);
            localStorage.setItem('idToken', this.idToken);
            localStorage.setItem('refreshToken', this.refreshToken);
        }
        
        return data;
    }

    signOut() {
        this.accessToken = null;
        this.idToken = null;
        this.refreshToken = null;
        this.currentUsername = null;
        this.pendingConfirmationUsername = null;
        
        localStorage.removeItem('accessToken');
        localStorage.removeItem('idToken');
        localStorage.removeItem('refreshToken');
        
        window.location.href = '/';
    }

    isAuthenticated() {
        return !!(this.accessToken || this.idToken);
    }

    getToken() {
        return this.idToken || this.accessToken;
    }

    getAuthHeaders() {
        const token = this.getToken();
        return {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        };
    }

    isTokenValid() {
        const token = this.getToken();
        if (!token) return false;
        
        try {
            const payload = JSON.parse(atob(token.split('.')[1]));
            const now = Math.floor(Date.now() / 1000);
            return payload.exp > now;
        } catch (error) {
            return false;
        }
    }

    getUserInfo() {
        const token = this.getToken();
        if (!token) return null;
        
        try {
            const payload = JSON.parse(atob(token.split('.')[1]));
            
            return {
                username: payload['cognito:username'] || payload.email || 'User',
                email: payload.email,
                name: payload.name,
                sub: payload.sub,
                given_name: payload.given_name,
                family_name: payload.family_name,
                preferred_username: payload.preferred_username
            };
        } catch (error) {
            return null;
        }
    }

    validatePassword(password) {
        const regex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
        return regex.test(password);
    }

    async refreshTokens() {
        if (!this.refreshToken) {
            throw new Error('No refresh token available');
        }

        try {
            const response = await fetch(`https://${this.config.domain}/oauth2/token`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                },
                body: new URLSearchParams({
                    grant_type: 'refresh_token',
                    client_id: this.config.clientId,
                    refresh_token: this.refreshToken
                })
            });

            if (response.ok) {
                const data = await response.json();
                
                this.accessToken = data.access_token;
                this.idToken = data.id_token;
                
                localStorage.setItem('accessToken', this.accessToken);
                localStorage.setItem('idToken', this.idToken);
                
                return true;
            } else {
                throw new Error('Token refresh failed');
            }
        } catch (error) {
            this.signOut();
            return false;
        }
    }
}

// Global instance
const auth = new CognitoAuth();