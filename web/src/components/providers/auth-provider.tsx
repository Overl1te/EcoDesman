"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

import {
  changePassword,
  fetchMe,
  login as apiLogin,
  loginWithSocial as apiLoginWithSocial,
  logout as apiLogout,
  register as apiRegister,
  updateProfile as apiUpdateProfile,
} from "@/lib/api";
import type { CurrentUser, ProfileUpdatePayload } from "@/lib/types";

type AuthModalMode = "login" | "register";

interface AuthModalState {
  isOpen: boolean;
  mode: AuthModalMode;
  returnTo: string;
}

interface AuthContextValue {
  user: CurrentUser | null;
  isAuthenticated: boolean;
  isBootstrapping: boolean;
  authModal: AuthModalState;
  login: (payload: { identifier: string; password: string }) => Promise<void>;
  loginWithSocial: (payload: {
    provider: string;
    code?: string;
    access_token?: string;
    redirect_uri?: string;
    accept_terms?: boolean;
    accept_privacy_policy?: boolean;
    accept_personal_data?: boolean;
    accept_public_personal_data_distribution?: boolean;
  }) => Promise<void>;
  register: (payload: {
    username: string;
    email: string;
    display_name?: string;
    phone?: string;
    password: string;
    password_confirmation: string;
    accept_terms: boolean;
    accept_privacy_policy: boolean;
    accept_personal_data: boolean;
    accept_public_personal_data_distribution?: boolean;
  }) => Promise<void>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
  updateProfile: (payload: ProfileUpdatePayload) => Promise<CurrentUser>;
  changePassword: (payload: {
    current_password: string;
    new_password: string;
    new_password_confirmation: string;
  }) => Promise<void>;
  openAuthModal: (options?: { mode?: AuthModalMode; returnTo?: string }) => void;
  closeAuthModal: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [isBootstrapping, setIsBootstrapping] = useState(true);
  const [authModal, setAuthModal] = useState<AuthModalState>({
    isOpen: false,
    mode: "login",
    returnTo: "/",
  });

  useEffect(() => {
    const bootstrap = async () => {
      try {
        const currentUser = await fetchMe();
        setUser(currentUser);
      } catch {
        setUser(null);
      } finally {
        setIsBootstrapping(false);
      }
    };

    void bootstrap();
  }, []);

  const login = useCallback(async (payload: { identifier: string; password: string }) => {
    const nextSession = await apiLogin(payload);
    setUser(nextSession.user);
  }, []);

  const loginWithSocial = useCallback(
    async (payload: {
      provider: string;
      code?: string;
      access_token?: string;
      redirect_uri?: string;
      accept_terms?: boolean;
      accept_privacy_policy?: boolean;
      accept_personal_data?: boolean;
      accept_public_personal_data_distribution?: boolean;
    }) => {
      const nextSession = await apiLoginWithSocial(payload);
      setUser(nextSession.user);
    },
    [],
  );

  const register = useCallback(
    async (payload: {
      username: string;
      email: string;
      display_name?: string;
      phone?: string;
      password: string;
      password_confirmation: string;
      accept_terms: boolean;
      accept_privacy_policy: boolean;
      accept_personal_data: boolean;
      accept_public_personal_data_distribution?: boolean;
    }) => {
      const nextSession = await apiRegister(payload);
      setUser(nextSession.user);
    },
    [],
  );

  const logout = useCallback(async () => {
    await apiLogout();
    setUser(null);
  }, []);

  const refreshUser = useCallback(async () => {
    try {
      const currentUser = await fetchMe();
      setUser(currentUser);
    } catch {
      setUser(null);
    }
  }, []);

  const updateProfile = useCallback(async (payload: ProfileUpdatePayload) => {
    const nextUser = await apiUpdateProfile(payload);
    setUser(nextUser);
    return nextUser;
  }, []);

  const changePasswordHandler = useCallback(
    async (payload: {
      current_password: string;
      new_password: string;
      new_password_confirmation: string;
    }) => {
      const nextSession = await changePassword(payload);
      setUser(nextSession.user);
    },
    [],
  );

  const openAuthModal = useCallback((options?: { mode?: AuthModalMode; returnTo?: string }) => {
    setAuthModal({
      isOpen: true,
      mode: options?.mode ?? "login",
      returnTo: options?.returnTo ?? "/",
    });
  }, []);

  const closeAuthModal = useCallback(() => {
    setAuthModal((current) => ({ ...current, isOpen: false }));
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      isAuthenticated: Boolean(user),
      isBootstrapping,
      authModal,
      login,
      loginWithSocial,
      register,
      logout,
      refreshUser,
      updateProfile,
      changePassword: changePasswordHandler,
      openAuthModal,
      closeAuthModal,
    }),
    [
      authModal,
      changePasswordHandler,
      closeAuthModal,
      isBootstrapping,
      login,
      loginWithSocial,
      logout,
      openAuthModal,
      refreshUser,
      register,
      updateProfile,
      user,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return context;
}
