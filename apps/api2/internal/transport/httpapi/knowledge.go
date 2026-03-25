package httpapi

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"api2/internal/domain/user"
	infra_ai "api2/internal/infra/ai"
	"api2/internal/sharedmodels"
	"api2/internal/store"

	"github.com/jackc/pgx/v5"
)

func (h *Handler) ListFolderSources(w http.ResponseWriter, r *http.Request, _ user.User) {
	folderID := strings.TrimSpace(r.PathValue("id"))
	if folderID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id is required"})
		return
	}

	if _, err := h.Queries.GetFolderByID(r.Context(), folderID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Folder not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	rows, err := h.Queries.ListSourcesByFolder(r.Context(), folderID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	out := make([]sharedmodels.Source, 0, len(rows))
	for _, row := range rows {
		out = append(out, toSharedSource(row))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) GetSource(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Source id is required"})
		return
	}

	row, err := h.Queries.GetSourceByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Source not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedSource(row))
}

func (h *Handler) CreateSource(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	folderID := strings.TrimSpace(r.PathValue("id"))
	if folderID == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Folder id is required"})
		return
	}

	if _, err := h.Queries.GetFolderByID(r.Context(), folderID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Folder not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	input, err := decodeSourceInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}

	row, err := h.Queries.CreateSource(r.Context(), store.CreateSourceParams{
		ID:        newSourceID(),
		FolderID:  folderID,
		Title:     input.Title,
		Content:   input.Content,
		CreatedBy: currentUser.Username,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusCreated, toSharedSource(row))
}

func (h *Handler) UpdateSource(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Source id is required"})
		return
	}

	input, err := decodeSourceInput(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: err.Error()})
		return
	}

	row, err := h.Queries.UpdateSource(r.Context(), store.UpdateSourceParams{
		ID:        id,
		Title:     input.Title,
		Content:   input.Content,
		UpdatedBy: currentUser.Username,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Source not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, toSharedSource(row))
}

func (h *Handler) DeleteSource(w http.ResponseWriter, r *http.Request, _ user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Source id is required"})
		return
	}

	if err := h.Queries.DeleteSource(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func decodeSourceInput(r *http.Request) (sourceInput, error) {
	var payload struct {
		Title   string `json:"title"`
		Content string `json:"content"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		return sourceInput{}, errors.New("Invalid request body")
	}

	content := strings.TrimSpace(payload.Content)
	if content == "" {
		return sourceInput{}, errors.New("Content is required")
	}

	return sourceInput{
		Title:   strings.TrimSpace(payload.Title),
		Content: content,
	}, nil
}

func newSourceID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "src_" + time.Now().UTC().Format("20060102150405")
	}
	return "src_" + hex.EncodeToString(b[:])
}

func toSharedSource(s store.Source) sharedmodels.Source {
	out := sharedmodels.Source{
		Id:        s.ID,
		FolderId:  s.FolderID,
		Title:     &s.Title,
		Content:   s.Content,
		CreatedBy: &s.CreatedBy,
		UpdatedBy: &s.UpdatedBy,
	}
	if s.CreatedTime.Valid {
		ts := s.CreatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.CreatedTime = &ts
	}
	if s.UpdatedTime.Valid {
		ts := s.UpdatedTime.Time.UTC().Format(time.RFC3339Nano)
		out.UpdatedTime = &ts
	}
	return out
}

type sourceInput struct {
	Title   string
	Content string
}

func (h *Handler) GenerateSourceConcepts(w http.ResponseWriter, r *http.Request, currentUser user.User) {
	id := strings.TrimSpace(r.PathValue("id"))
	if id == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Source id is required"})
		return
	}

	src, err := h.Queries.GetSourceByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusNotFound, ErrorResponse{Detail: "Source not found"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	folder, err := h.Queries.GetFolderByID(r.Context(), src.FolderID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	domain := ""
	if folder.Domain != nil && strings.TrimSpace(*folder.Domain) != "" {
		domain = strings.TrimSpace(*folder.Domain)
	} else {
		domain = folder.Name
	}

	if h.AIClient == nil {
		writeJSON(w, http.StatusServiceUnavailable, ErrorResponse{Detail: "AI service not configured"})
		return
	}

	// Mint a short-lived service token so the AI call succeeds regardless of
	// the calling user's role (api2 has already authenticated and authorised).
	serviceToken, err := h.AuthService.Tokens.CreateAccessToken("api2-service", "teacher")
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Internal server error"})
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	extracted, err := h.AIClient.ExtractConcepts(ctx, serviceToken, infra_ai.ExtractConceptsRequest{
		SourceText: src.Content,
		Domain:     domain,
	})
	if err != nil {
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: err.Error()})
		return
	}

	out := make([]sharedmodels.Concept, 0, len(extracted))
	for _, ec := range extracted {
		row, createErr := h.Queries.CreateConcept(r.Context(), store.CreateConceptParams{
			ID:            newConceptID(),
			CanonicalName: ec.CanonicalName,
			Domain:        ec.Domain,
			Description:   ec.Description,
			Tags:          ec.Tags,
			CreatedBy:     currentUser.Username,
			UpdatedBy:     currentUser.Username,
		})
		if createErr != nil {
			continue
		}
		_ = h.Queries.LinkSourceConcept(r.Context(), id, row.ID, currentUser.Username)
		out = append(out, toSharedConcept(row))
	}

	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) FetchURLContent(w http.ResponseWriter, r *http.Request, _ user.User) {
	var body struct {
		URL string `json:"url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Invalid request body"})
		return
	}

	rawURL := strings.TrimSpace(body.URL)
	if rawURL == "" {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "URL is required"})
		return
	}

	parsed, err := url.Parse(rawURL)
	if err != nil || (parsed.Scheme != "http" && parsed.Scheme != "https") {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "URL must use http or https"})
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, ErrorResponse{Detail: "Invalid URL"})
		return
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; T2T-Bot/1.0)")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, ErrorResponse{Detail: "Failed to fetch URL"})
		return
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, ErrorResponse{Detail: "Failed to read response"})
		return
	}

	htmlContent := string(bodyBytes)
	writeJSON(w, http.StatusOK, map[string]string{
		"title":   extractHTMLTitle(htmlContent),
		"content": extractHTMLText(htmlContent),
	})
}

var (
	reTitleTag = regexp.MustCompile(`(?is)<title[^>]*>(.*?)</title>`)
	reMain     = regexp.MustCompile(`(?is)<main[^>]*>(.*?)</main>`)
	reArticle  = regexp.MustCompile(`(?is)<article[^>]*>(.*?)</article>`)
	reScript   = regexp.MustCompile(`(?is)<script[^>]*>.*?</script>`)
	reStyle    = regexp.MustCompile(`(?is)<style[^>]*>.*?</style>`)
	reHead     = regexp.MustCompile(`(?is)<head[^>]*>.*?</head>`)
	reNav      = regexp.MustCompile(`(?is)<nav[^>]*>.*?</nav>`)
	reHeader   = regexp.MustCompile(`(?is)<header[^>]*>.*?</header>`)
	reFooter   = regexp.MustCompile(`(?is)<footer[^>]*>.*?</footer>`)
	reAside    = regexp.MustCompile(`(?is)<aside[^>]*>.*?</aside>`)
	reTag      = regexp.MustCompile(`<[^>]+>`)
	reSpaces   = regexp.MustCompile(`\s+`)
)

var htmlEntities = strings.NewReplacer(
	"&amp;", "&", "&lt;", "<", "&gt;", ">",
	"&quot;", `"`, "&#39;", "'", "&nbsp;", " ",
)

func extractHTMLTitle(html string) string {
	m := reTitleTag.FindStringSubmatch(html)
	if len(m) > 1 {
		return strings.TrimSpace(m[1])
	}
	return ""
}

func extractHTMLText(html string) string {
	// Remove scripts, styles, head first
	html = reScript.ReplaceAllString(html, "")
	html = reStyle.ReplaceAllString(html, "")
	html = reHead.ReplaceAllString(html, "")

	// Prefer <main> content, then <article>, then full body minus boilerplate
	if m := reMain.FindStringSubmatch(html); len(m) > 1 {
		html = m[1]
	} else if m := reArticle.FindStringSubmatch(html); len(m) > 1 {
		html = m[1]
	} else {
		html = reNav.ReplaceAllString(html, "")
		html = reHeader.ReplaceAllString(html, "")
		html = reFooter.ReplaceAllString(html, "")
		html = reAside.ReplaceAllString(html, "")
	}

	html = reTag.ReplaceAllString(html, " ")
	html = htmlEntities.Replace(html)
	return strings.TrimSpace(reSpaces.ReplaceAllString(html, " "))
}
