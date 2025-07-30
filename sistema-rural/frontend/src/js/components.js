// Modal Component
class Modal {
    constructor(modalId) {
        this.modal = document.getElementById(modalId);
        this.init();
    }

    // Helper to get correct path for localhost
    getPath(htmlFile) {
        const isLocalhost = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
        return isLocalhost ? `/src/${htmlFile}` : `/${htmlFile}`;
    }

    init() {
        this.modal.addEventListener('click', (e) => {
            if (e.target === this.modal) {
                this.close();
            }
        });

        const closeBtn = this.modal.querySelector('.modal-close');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => this.close());
        }

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen()) {
                this.close();
            }
        });
    }

    open() {
        this.modal.classList.remove('hidden');
        document.body.style.overflow = 'hidden';
        
        const firstButton = this.modal.querySelector('button:not([type="hidden"])');
        if (firstButton) {
            setTimeout(() => firstButton.focus(), 100);
        }
    }

    close() {
        this.modal.classList.add('hidden');
        document.body.style.overflow = '';
    }

    isOpen() {
        return !this.modal.classList.contains('hidden');
    }
}

// Auth Form Component
class AuthForm {
    constructor(modalInstance) {
        this.modal = modalInstance;
        this.currentTab = 'login';
        this.statusEl = document.getElementById('authStatus');
        
        this.loginForm = document.getElementById('loginForm');
        this.signupForm = document.getElementById('signupForm');
        this.confirmationForm = document.getElementById('confirmationForm');
        
        this.loginTabBtn = document.getElementById('loginTabBtn');
        this.signupTabBtn = document.getElementById('signupTabBtn');
        
        this.loginFormDiv = document.getElementById('loginFormDiv');
        this.signupFormDiv = document.getElementById('signupFormDiv');
        this.confirmationDiv = document.getElementById('confirmationDiv');
        
        this.init();
    }

    // Helper to get correct path for localhost
    getPath(htmlFile) {
        const isLocalhost = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
        return isLocalhost ? `/src/${htmlFile}` : `/${htmlFile}`;
    }

    init() {
        this.bindTabEvents();
        this.bindFormEvents();
        this.setupPasswordValidation();
    }

    bindTabEvents() {
        if (this.loginTabBtn) this.loginTabBtn.addEventListener('click', () => this.switchTab('login'));
        if (this.signupTabBtn) this.signupTabBtn.addEventListener('click', () => this.switchTab('signup'));
    }

    bindFormEvents() {
        if (this.loginForm) {
            this.loginForm.addEventListener('submit', (e) => this.handleLogin(e));
        }
        
        if (this.signupForm) {
            this.signupForm.addEventListener('submit', (e) => this.handleSignup(e));
        }
        
        if (this.confirmationForm) {
            this.confirmationForm.addEventListener('submit', (e) => this.handleConfirmation(e));
        }
        
        const resendBtn = document.getElementById('resendCodeBtn');
        if (resendBtn) {
            resendBtn.addEventListener('click', () => this.handleResendCode());
        }
    }

    setupPasswordValidation() {
        const signupPasswordInput = document.getElementById('signupPassword');
        const passwordHint = document.getElementById('passwordHint');

        if (signupPasswordInput && passwordHint) {
            signupPasswordInput.addEventListener('input', () => {
                const password = signupPasswordInput.value;
                const isValid = auth.validatePassword(password);
                
                passwordHint.classList.toggle('error', !isValid && password.length > 0);
                passwordHint.textContent = isValid || password.length === 0 
                    ? 'Mínimo 8 caracteres, maiúscula, minúscula e número'
                    : '❌ Senha não atende aos requisitos';
            });
        }
    }

    switchTab(tab) {
        this.currentTab = tab;

        if (this.loginTabBtn) this.loginTabBtn.classList.toggle('active', tab === 'login');
        if (this.signupTabBtn) this.signupTabBtn.classList.toggle('active', tab === 'signup');

        if (this.loginFormDiv) this.loginFormDiv.classList.toggle('hidden', tab !== 'login');
        if (this.signupFormDiv) this.signupFormDiv.classList.toggle('hidden', tab !== 'signup');
        if (this.confirmationDiv) this.confirmationDiv.classList.add('hidden');

        const modalTitle = document.getElementById('modalTitle');
        if (modalTitle) {
            modalTitle.textContent = tab === 'login' ? 'Acessar Sistema' : 'Criar Conta';
        }

        this.clearStatus();
        
        setTimeout(() => {
            const activeForm = tab === 'login' ? this.loginFormDiv : this.signupFormDiv;
            if (activeForm) {
                const firstInput = activeForm.querySelector('input');
                if (firstInput) firstInput.focus();
            }
        }, 100);
    }

    showConfirmationForm() {
        const modalTabs = document.querySelector('.modal-tabs');
        if (modalTabs) modalTabs.style.display = 'none';
        
        if (this.loginFormDiv) this.loginFormDiv.classList.add('hidden');
        if (this.signupFormDiv) this.signupFormDiv.classList.add('hidden');
        if (this.confirmationDiv) this.confirmationDiv.classList.remove('hidden');
        
        setTimeout(() => {
            const confirmInput = document.getElementById('confirmCode');
            if (confirmInput) confirmInput.focus();
        }, 100);
    }

    resetToLogin() {
        const modalTabs = document.querySelector('.modal-tabs');
        if (modalTabs) modalTabs.style.display = 'flex';
        this.switchTab('login');
    }

    async handleLogin(e) {
        e.preventDefault();
        
        const emailEl = document.getElementById('email');
        const passwordEl = document.getElementById('password');
        const submitBtn = document.getElementById('submitLogin');
        
        if (!emailEl || !passwordEl || !submitBtn) return;
        
        const email = emailEl.value.trim();
        const password = passwordEl.value.trim();

        if (!email || !password) {
            this.showStatus('Preencha todos os campos.', 'error');
            return;
        }

        this.setLoading(submitBtn, true, 'Entrando...');
        
        try {
            const result = await auth.signIn(email, password);
            
            if (result.AuthenticationResult) {
                this.showStatus('Login realizado com sucesso!', 'success');
                this.modal.close();
                this.clearForm();
                
                if (window.updateAuthUI) {
                    window.updateAuthUI();
                }
                setTimeout(() => {
                    window.location.href = this.getPath('dashboard.html');
                }, 500);
                
            } else if (result.ChallengeName === 'NEW_PASSWORD_REQUIRED') {
                const newPassword = prompt('Digite uma nova senha (mín. 8 chars, maiúscula, minúscula e número):');
                if (newPassword && auth.validatePassword(newPassword)) {
                    const finalResult = await auth.respondToNewPasswordRequired(result.Session, newPassword);
                    if (finalResult.AuthenticationResult) {
                        this.showStatus('Senha alterada e login realizado!', 'success');
                        this.modal.close();
                        if (window.updateAuthUI) {
                            window.updateAuthUI();
                        }
                        setTimeout(() => {
                            window.location.href = this.getPath('dashboard.html');
                        }, 500);
                    }
                } else {
                    this.showStatus('Nova senha inválida.', 'error');
                }
            } else {
                const errorMessage = result.message || result.__type || 'Erro no login. Verifique suas credenciais.';
                this.showStatus(errorMessage, 'error');
            }
        } catch (error) {
            this.showStatus(`Erro: ${error.message}`, 'error');
        } finally {
            this.setLoading(submitBtn, false, 'Entrar');
        }
    }

    async handleSignup(e) {
        e.preventDefault();
        
        const emailEl = document.getElementById('signupEmail');
        const passwordEl = document.getElementById('signupPassword');
        const confirmPasswordEl = document.getElementById('confirmPassword');
        const submitBtn = document.getElementById('submitSignup');
        
        if (!emailEl || !passwordEl || !confirmPasswordEl || !submitBtn) return;
        
        const email = emailEl.value.trim();
        const password = passwordEl.value;
        const confirmPassword = confirmPasswordEl.value;
        
        if (!email || !password || !confirmPassword) {
            this.showStatus('Preencha todos os campos.', 'error');
            return;
        }

        if (!auth.validatePassword(password)) {
            this.showStatus('Senha não atende aos requisitos de segurança.', 'error');
            return;
        }

        if (password !== confirmPassword) {
            this.showStatus('As senhas não coincidem.', 'error');
            return;
        }

        this.setLoading(submitBtn, true, 'Cadastrando...');
        
        try {
            const result = await auth.signUp(email, password);
            
            if (result.UserSub) {
                this.showStatus('Cadastro realizado! Verificando email...', 'success');
                setTimeout(() => this.showConfirmationForm(), 1500);
            } else {
                let errorMessage = 'Erro no cadastro';
                switch (result.__type) {
                    case 'UsernameExistsException':
                        errorMessage = 'Este email já está cadastrado';
                        break;
                    case 'InvalidPasswordException':
                        errorMessage = 'Senha não atende aos requisitos';
                        break;
                    case 'InvalidParameterException':
                        errorMessage = 'Email inválido';
                        break;
                    default:
                        errorMessage = result.message || 'Erro no cadastro';
                }
                this.showStatus(errorMessage, 'error');
            }
        } catch (error) {
            this.showStatus(`Erro: ${error.message}`, 'error');
        } finally {
            this.setLoading(submitBtn, false, 'Cadastrar');
        }
    }

    async handleConfirmation(e) {
        e.preventDefault();
        
        const codeEl = document.getElementById('confirmCode');
        const submitBtn = document.getElementById('submitConfirm');
        
        if (!codeEl || !submitBtn) return;
        
        const code = codeEl.value.trim();
        
        if (!code) {
            this.showStatus('Digite o código de confirmação.', 'error');
            return;
        }

        this.setLoading(submitBtn, true, 'Confirmando...');
        
        try {
            const result = await auth.confirmSignUp(auth.pendingConfirmationUsername, code);
            
            if (result.__type) {
                let errorMessage = 'Código inválido';
                switch (result.__type) {
                    case 'CodeMismatchException':
                        errorMessage = 'Código incorreto';
                        break;
                    case 'ExpiredCodeException':
                        errorMessage = 'Código expirado';
                        break;
                    default:
                        errorMessage = result.message || 'Código inválido';
                }
                this.showStatus(errorMessage, 'error');
            } else {
                this.showStatus('Email confirmado! Você já pode fazer login.', 'success');
                setTimeout(() => this.resetToLogin(), 2000);
            }
        } catch (error) {
            this.showStatus(`Erro: ${error.message}`, 'error');
        } finally {
            this.setLoading(submitBtn, false, 'Confirmar');
        }
    }

    async handleResendCode() {
        const resendBtn = document.getElementById('resendCodeBtn');
        if (!resendBtn || !auth.pendingConfirmationUsername) return;
        
        resendBtn.disabled = true;
        resendBtn.textContent = 'Enviando...';
        
        try {
            await auth.resendConfirmationCode(auth.pendingConfirmationUsername);
            this.showStatus('Código reenviado para seu email', 'success');
        } catch (error) {
            this.showStatus('Erro ao reenviar código', 'error');
        } finally {
            resendBtn.disabled = false;
            resendBtn.textContent = 'Reenviar';
        }
    }

    setLoading(button, loading, text) {
        if (!button) return;
        button.disabled = loading;
        button.textContent = loading ? text : button.id.includes('Login') ? 'Entrar' : 
                             button.id.includes('Signup') ? 'Cadastrar' : 'Confirmar';
    }

    showStatus(message, type) {
        if (!this.statusEl) return;
        
        this.statusEl.textContent = message;
        this.statusEl.className = `auth-status ${type}`;
        this.statusEl.classList.remove('hidden');
        
        if (type === 'success') {
            setTimeout(() => this.clearStatus(), 3000);
        }
    }

    clearStatus() {
        if (this.statusEl) {
            this.statusEl.textContent = '';
            this.statusEl.className = 'auth-status hidden';
        }
    }

    clearForm() {
        if (this.loginForm) this.loginForm.reset();
        if (this.signupForm) this.signupForm.reset();
        if (this.confirmationForm) this.confirmationForm.reset();
        this.clearStatus();
    }
}

// User Menu Component
class UserMenu {
    constructor() {
        this.userMenu = document.getElementById('userMenu');
        this.userAvatar = document.getElementById('userAvatar');
        this.userInitial = document.getElementById('userInitial');
        this.dropdown = document.getElementById('userDropdown');
        this.init();
    }

    init() {
        this.bindLogoutButtons();

        if (this.userMenu && this.dropdown) {
            let timeoutId;
            
            this.userMenu.addEventListener('mouseenter', () => {
                clearTimeout(timeoutId);
                this.dropdown.style.opacity = '1';
                this.dropdown.style.visibility = 'visible';
                this.dropdown.style.transform = 'translateY(0)';
            });
            
            this.userMenu.addEventListener('mouseleave', () => {
                timeoutId = setTimeout(() => {
                    this.dropdown.style.opacity = '0';
                    this.dropdown.style.visibility = 'hidden';
                    this.dropdown.style.transform = 'translateY(-10px)';
                }, 100);
            });
        }
    }

    bindLogoutButtons() {
        const logoutBtns = document.querySelectorAll('#logoutBtn, .logout-btn');
        
        logoutBtns.forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                this.handleLogout();
            });
        });

        if (logoutBtns.length === 0) {
            setTimeout(() => this.bindLogoutButtons(), 1000);
        }
    }

    updateUser(userInfo) {
        if (this.userInitial && userInfo) {
            const initial = userInfo.name ? userInfo.name.charAt(0) : 
                           userInfo.email ? userInfo.email.charAt(0) :
                           userInfo.username ? userInfo.username.charAt(0) : 'U';
            
            this.userInitial.textContent = initial.toUpperCase();
        }
    }

    handleLogout() {
        auth.signOut();
        
        if (window.updateAuthUI) {
            window.updateAuthUI();
        }
        
        if (window.toast) {
            window.toast.show('Logout realizado com sucesso', 'success');
        }
    }
}

// Simple Toast Component
class StatusToast {
    constructor() {
        this.container = this.createContainer();
        document.body.appendChild(this.container);
    }

    createContainer() {
        const container = document.createElement('div');
        container.className = 'toast-container';
        container.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 10000;
            display: flex;
            flex-direction: column;
            gap: 8px;
        `;
        return container;
    }

    show(message, type = 'info', duration = 5000) {
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.textContent = message;
        
        const colors = {
            success: '#d4edda',
            error: '#f8d7da',
            warning: '#fff3cd',
            info: '#d1ecf1'
        };
        
        const textColors = {
            success: '#155724',
            error: '#721c24',
            warning: '#856404',
            info: '#0c5460'
        };

        toast.style.cssText = `
            background: ${colors[type] || colors.info};
            color: ${textColors[type] || textColors.info};
            padding: 12px 16px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
            transform: translateX(100%);
            transition: transform 0.3s ease-in-out;
            max-width: 400px;
            font-weight: 500;
        `;

        this.container.appendChild(toast);

        setTimeout(() => {
            toast.style.transform = 'translateX(0)';
        }, 10);

        setTimeout(() => {
            toast.style.transform = 'translateX(100%)';
            setTimeout(() => {
                if (toast.parentNode) {
                    toast.parentNode.removeChild(toast);
                }
            }, 300);
        }, duration);

        return toast;
    }
}

// Route Protection
class RouteProtection {
    constructor() {
        this.protectedPages = ['dashboard.html', 'mapeamento.html'];
        this.init();
    }

    init() {
        this.checkCurrentRoute();
    }

    checkCurrentRoute() {
        const currentPage = window.location.pathname.split('/').pop() || 'index.html';
        
        if (this.protectedPages.includes(currentPage)) {
            if (!auth.isAuthenticated() || !auth.isTokenValid()) {
                window.location.href = '/';
                return false;
            }
        }
        return true;
    }

    protect(callback) {
        if (this.checkCurrentRoute()) {
            callback();
        }
    }
}

// Global instances
window.modal = null;
window.authForm = null;
window.userMenu = null;
window.toast = null;
window.routeProtection = null;

// Initialize components
document.addEventListener('DOMContentLoaded', () => {
    window.modal = new Modal('loginModal');
    window.authForm = new AuthForm(window.modal);
    window.userMenu = new UserMenu();
    window.toast = new StatusToast();
    window.routeProtection = new RouteProtection();
    
    if (window.updateAuthUI && auth.isAuthenticated()) {
        window.updateAuthUI();
    }
    
    // Consolidated logout handler
    document.addEventListener('click', (e) => {
        if (e.target.id === 'logoutBtn' || 
            e.target.classList.contains('logout-btn') ||
            e.target.closest('#logoutBtn') ||
            e.target.closest('.logout-btn')) {
            
            e.preventDefault();
            auth.signOut();
            if (window.toast) {
                window.toast.show('Logout realizado com sucesso', 'success');
            }
        }
    });
});