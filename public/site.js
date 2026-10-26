(() => {
    const header = document.querySelector("[data-header]");
    const nav = document.querySelector("#site-navigation");
    const navToggle = document.querySelector("[data-nav-toggle]");
    const navLinks = nav ? Array.from(nav.querySelectorAll("a")) : [];

    function setNavigation(open) {
        if (!header || !nav || !navToggle) return;

        nav.classList.toggle("is-open", open);
        header.classList.toggle("nav-open", open);
        navToggle.setAttribute("aria-expanded", String(open));
        navToggle.setAttribute("aria-label", open ? "Close navigation" : "Open navigation");
    }

    if (navToggle) {
        navToggle.addEventListener("click", () => {
            setNavigation(navToggle.getAttribute("aria-expanded") !== "true");
        });
    }

    navLinks.forEach((link) => link.addEventListener("click", () => setNavigation(false)));

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && navToggle?.getAttribute("aria-expanded") === "true") {
            setNavigation(false);
            navToggle.focus();
        }
    });

    document.addEventListener("click", (event) => {
        if (!header || !navToggle || navToggle.getAttribute("aria-expanded") !== "true") return;
        if (!header.contains(event.target)) setNavigation(false);
    });

    window.addEventListener("resize", () => {
        if (window.innerWidth > 960) setNavigation(false);
    });

    if (header) {
        const updateHeader = () => header.classList.toggle("is-scrolled", window.scrollY > 12);
        updateHeader();
        window.addEventListener("scroll", updateHeader, { passive: true });
    }

    const copyTimers = new WeakMap();

    async function copyText(text) {
        if (navigator.clipboard && window.isSecureContext) {
            await navigator.clipboard.writeText(text);
            return;
        }

        const field = document.createElement("textarea");
        field.value = text;
        field.setAttribute("readonly", "");
        field.style.position = "fixed";
        field.style.opacity = "0";
        document.body.appendChild(field);
        field.select();
        const copied = document.execCommand("copy");
        field.remove();

        if (!copied) throw new Error("Copy failed");
    }

    document.querySelectorAll("[data-copy]").forEach((button) => {
        button.addEventListener("click", async () => {
            const label = button.querySelector(".copy-label");
            const original = label ? label.textContent : button.getAttribute("aria-label");
            const clearTimer = copyTimers.get(button);

            if (clearTimer) window.clearTimeout(clearTimer);

            try {
                await copyText(button.dataset.copy);
                button.classList.add("is-copied");
                if (label) label.textContent = "Copied";
                button.setAttribute("aria-label", "Copied to clipboard");
            } catch {
                button.classList.remove("is-copied");
                if (label) label.textContent = "Select";
                button.setAttribute("aria-label", "Select and copy the command");
            }

            copyTimers.set(
                button,
                window.setTimeout(() => {
                    button.classList.remove("is-copied");
                    if (label) label.textContent = original;
                    button.setAttribute("aria-label", button.dataset.copy ? "Copy command" : "Copy");
                }, 2000),
            );
        });
    });

    const releaseEndpoint = "https://api.github.com/repos/onjoakimsmind/serverdeck/releases/latest";
    const releaseLinks = document.querySelectorAll(".js-release-link");
    const releaseTags = document.querySelectorAll(".js-release-tag, .js-release-version");
    const releaseDates = document.querySelectorAll(".js-release-date");
    const releaseSizes = document.querySelectorAll(".js-release-size");

    function readableDate(value) {
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return null;

        return new Intl.DateTimeFormat("en", {
            month: "short",
            day: "numeric",
            year: "numeric",
            timeZone: "UTC",
        }).format(date);
    }

    function readableSize(bytes) {
        if (!Number.isFinite(bytes) || bytes <= 0) return null;

        return `${new Intl.NumberFormat("en", { maximumFractionDigits: 1 }).format(bytes / 1000000)} MB`;
    }

    fetch(releaseEndpoint, {
        cache: "no-store",
        headers: { Accept: "application/vnd.github+json" },
    })
        .then((response) => (response.ok ? response.json() : null))
        .then((release) => {
            if (!release || typeof release.tag_name !== "string") return;

            const tag = release.tag_name.startsWith("v") ? release.tag_name : `v${release.tag_name}`;
            const releaseUrl = String(release.html_url || "");

            if (!/^v[0-9A-Za-z._-]+$/.test(tag)) return;

            releaseTags.forEach((element) => {
                element.textContent = tag;
            });

            if (/^https:\/\/github\.com\/onjoakimsmind\/serverdeck\/releases\//.test(releaseUrl)) {
                releaseLinks.forEach((link) => {
                    link.href = releaseUrl;
                });
            }

            const published = readableDate(release.published_at);
            if (published) {
                releaseDates.forEach((element) => {
                    element.textContent = published;
                });
            }

            const archive = Array.isArray(release.assets)
                ? release.assets.find((asset) => String(asset.name || "").endsWith(".tar.gz"))
                : null;

            const size = archive ? readableSize(Number(archive.size)) : null;
            if (size) {
                releaseSizes.forEach((element) => {
                    element.textContent = size;
                });
            }
        })
        .catch(() => {
            // Static release details remain in place when GitHub is unavailable.
        });

    document.querySelectorAll("[data-year]").forEach((element) => {
        element.textContent = String(new Date().getFullYear());
    });
})();
