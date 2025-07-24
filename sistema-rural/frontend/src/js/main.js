// Main Application Controller - Simplified
class App {
    constructor() {
        this.init();
    }

    init() {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.onReady());
        } else {
            this.onReady();
        }
    }

    onReady() {
        this.bindEvents();
        this.updateAuthUI();
        this.checkTokenValidity();
    }

    bindEvents() {
        // Login button clicks
        const loginBtns = [
            document.getElementById('loginBtn'),
            document.getElementById('heroLoginBtn'),
            document.getElementById('projectLoginBtn'),
            document.getElementById('ctaLoginBtn')
        ].filter(btn => btn);

        loginBtns.forEach(btn => {
            btn.addEventListener('click', () => this.openLoginModal());
        });

        // Navigation active state
        this.updateActiveNavLink();
    }

    openLoginModal() {
        if (auth.isAuthenticated()) {
            window.location.href = 'dashboard.html';
        } else {
            if (window.modal) {
                window.modal.open();
            }
        }
    }

    updateAuthUI() {
        const loginBtn = document.getElementById('loginBtn');
        const userMenu = document.getElementById('userMenu');
        
        if (auth.isAuthenticated() && auth.isTokenValid()) {
            if (loginBtn) loginBtn.style.display = 'none';
            if (userMenu) {
                userMenu.classList.remove('hidden');
                userMenu.style.display = 'block';
                this.updateAvatarDirect();
                
                if (window.userMenu) {
                    const userInfo = auth.getUserInfo();
                    if (userInfo) {
                        window.userMenu.updateUser(userInfo);
                    }
                }
            }
        } else {
            if (loginBtn) {
                loginBtn.style.display = 'block';
                loginBtn.textContent = 'Login';
            }
            if (userMenu) {
                userMenu.classList.add('hidden');
                userMenu.style.display = 'none';
            }
        }
    }

    updateAvatarDirect() {
        const userInitial = document.getElementById('userInitial');
        if (userInitial) {
            const userInfo = auth.getUserInfo();
            if (userInfo) {
                const initial = userInfo.name ? userInfo.name.charAt(0) : 
                               userInfo.email ? userInfo.email.charAt(0) :
                               userInfo.username ? userInfo.username.charAt(0) : 'U';
                
                userInitial.textContent = initial.toUpperCase();
            }
        }
    }

    updateActiveNavLink() {
        const currentPage = window.location.pathname.split('/').pop() || 'index.html';
        const navLinks = document.querySelectorAll('.nav-link');
        
        navLinks.forEach(link => {
            link.classList.remove('active');
            const href = link.getAttribute('href');
            
            if (
                (currentPage === 'index.html' && href === '/') ||
                (currentPage === href) ||
                (currentPage === '' && href === '/')
            ) {
                link.classList.add('active');
            }
        });
    }

    checkTokenValidity() {
        if (auth.isAuthenticated() && !auth.isTokenValid()) {
            auth.signOut();
            this.updateAuthUI();
            
            if (window.toast) {
                window.toast.show('Sessão expirada. Faça login novamente.', 'warning');
            }
        }
    }

    showStatus(message, type = 'info') {
        if (window.toast) {
            window.toast.show(message, type);
        } else {
            alert(message);
        }
    }
}

// Global app instance
window.app = null;

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    window.app = new App();
});

// Global functions
window.updateAuthUI = () => {
    if (window.app) {
        window.app.updateAuthUI();
    }
};

window.showStatus = (message, type) => {
    if (window.app) {
        window.app.showStatus(message, type);
    }
};

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    if (e.altKey && e.key === 'l') {
        e.preventDefault();
        if (window.app && !auth.isAuthenticated()) {
            window.app.openLoginModal();
        }
    }
    
    if (e.altKey && e.key === 'h') {
        e.preventDefault();
        window.location.href = '/';
    }
    
    if (e.altKey && e.key === 'd') {
        e.preventDefault();
        if (auth.isAuthenticated()) {
            window.location.href = 'dashboard.html';
        }
    }
});