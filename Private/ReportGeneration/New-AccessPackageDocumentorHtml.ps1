function New-AccessPackageDocumentorHtml {
	<#!
	.SYNOPSIS
		Creates an interactive HTML documentation report for Access Packages.

	.DESCRIPTION
		Generates a standalone HTML file with Cytoscape.js, light/dark theme toggle, zoom controls, search, and
		export-to-PNG. Accepts pre-shaped node/edge data from Convert-AccessPackageDocumentorData.

	.PARAMETER Data
		PSCustomObject with Nodes, Edges, Stats.

	.PARAMETER OutputPath
		Destination HTML file path.

	.PARAMETER Theme
		Preferred theme (Light, Dark, or Auto). Auto aligns with browser/OS preference.
	#>
	[CmdletBinding(SupportsShouldProcess = $true)] param(
		[Parameter(Mandatory)][psobject]$Data,
		[Parameter(Mandatory)][string]$OutputPath,
		[ValidateSet('Auto', 'Light', 'Dark')][string]$Theme = 'Auto'
	)

	# Load logo data
	. "$PSScriptRoot\LogoData.ps1"

	$payload = [pscustomobject]@{
		nodes = $Data.Nodes
		edges = $Data.Edges
		stats = $Data.Stats
	}
	$jsonRaw = $payload | ConvertTo-Json -Depth 12 -Compress
	$jsonBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jsonRaw))

	# Use a single-quoted here-string so PowerShell does not expand anything, then replace placeholders.
	$htmlTemplate = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Access Package Documentor</title>
<style>
	:root {
		--bg: #f5f7fb;
		--panel: #ffffff;
		--text: #1f2937;
		--muted: #6b7280;
		--accent: #2563eb;
		--border: #e5e7eb;
	}
	[data-theme="dark"] {
		--bg: #0f172a;
		--panel: #111827;
		--text: #e5e7eb;
		--muted: #9ca3af;
		--accent: #60a5fa;
		--border: #1f2937;
	}
	body {
		margin: 0;
		font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
		background: var(--bg);
		color: var(--text);
		display: grid;
		grid-template-rows: auto 1fr auto;
		height: 100vh;
	}
	header {
		display: grid;
		/* 3-column header: left stats | search | right actions */
		grid-template-columns: minmax(280px, 1fr) minmax(180px, 520px) minmax(280px, 1fr);
		gap: 12px;
		align-items: center;
		padding: 12px 18px;
		background: var(--panel);
		border-bottom: 1px solid var(--border);
		position: sticky;
		top: 0;
		z-index: 2;
		/* Allow wrapping instead of overlapping when space is tight */
		overflow-x: hidden;
		white-space: normal;
	}
	.header-left,
	.header-center,
	.header-right { display: flex; align-items: center; gap: 10px; min-width: 0; }
	.header-left { justify-content: flex-start; flex-wrap: wrap; flex: 1 1 auto; }
	.header-left > * { white-space: nowrap; }
	.header-center { justify-content: center; min-width: 0; }
	.header-right { justify-content: flex-end; flex-wrap: wrap; flex: 1 1 auto; }
	button, input[type="search"] {
		border: 1px solid var(--border);
		background: var(--panel);
		color: var(--text);
		padding: 8px 12px;
		border-radius: 8px;
		font-size: 14px;
		cursor: pointer;
	}
	button:hover { border-color: var(--accent); }
	#search {
		/* Shrinks/grows with available space without covering buttons or stats */
		width: 100%;
		max-width: 520px;
		min-width: 160px;
		box-sizing: border-box;
	}

	/* Narrow viewports: stack header sections so nothing overlaps */
	@media (max-width: 1100px) {
		header {
			grid-template-columns: 1fr;
			grid-template-rows: auto auto auto;
		}
		.header-left { justify-content: center; }
		.header-center { justify-content: stretch; }
		.header-right { justify-content: center; }
		#search { max-width: 100%; width: 100%; }
	}
	#container { display: flex; height: 100%; min-height: 0; }
	#cy-wrapper { position: relative; flex: 1 1 auto; min-width: 0; height: 100%; background: var(--bg); }
	#cy { position: absolute; inset: 0; width: 100%; height: 100%; box-sizing: border-box; }
	#cy-watermark {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		pointer-events: none;
		font-weight: 700;
		font-size: 32px;
		color: rgba(31,41,55,0.10);
		letter-spacing: 0.06em;
		user-select: none;
	}
	[data-theme="dark"] #cy-watermark { color: rgba(229,231,235,0.12); mix-blend-mode: screen; }
	#details {
		position: relative;
		width: 380px;
		max-width: 420px;
		min-width: 260px;
		border-left: 1px solid var(--border);
		background: var(--panel);
		padding: 16px;
		overflow-y: auto;
		transition: width 0.18s ease, padding 0.18s ease;
	}
	#details.collapsed {
		width: 36px !important;
		min-width: 36px;
		max-width: 36px;
		padding: 12px 6px;
		overflow: hidden;
	}
	#details-toggle {
		position: absolute;
		top: 12px;
		left: -14px;
		width: 22px;
		height: 32px;
		border: 1px solid var(--border);
		border-radius: 6px;
		background: var(--panel);
		color: var(--muted);
		cursor: pointer;
		box-shadow: 0 2px 6px rgba(0,0,0,0.08);
	}
	#details.collapsed #detail-title,
	#details.collapsed #detail-body { display: none; }
	.stat-pill { display: inline-flex; gap: 6px; align-items: center; padding: 6px 10px; border: 1px solid var(--border); border-radius: 999px; margin-right: 8px; flex-shrink: 0; }
	.badge { display: inline-block; padding: 4px 8px; border-radius: 6px; background: rgba(37,99,235,0.12); color: var(--accent); font-size: 12px; }
	.small { color: var(--muted); font-size: 12px; }
	.tag { display: inline-block; padding: 4px 8px; margin: 2px; border-radius: 6px; border: 1px solid var(--border); }
	.detail-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 10px; }
	.detail-chip { border: 1px solid var(--border); border-radius: 10px; padding: 10px 12px; background: var(--panel); box-shadow: 0 4px 10px rgba(0,0,0,0.03); }
	.detail-chip .label { display: block; font-weight: 600; margin-bottom: 6px; color: var(--text); }
	.detail-chip .value { font-family: 'Cascadia Code', 'SFMono-Regular', ui-monospace, monospace; font-size: 12px; color: var(--muted); white-space: pre-wrap; }
	.detail-chip .badge { background: rgba(16,185,129,0.12); color: #10b981; }
	.detail-chip .badge.bad { background: rgba(239,68,68,0.12); color: #ef4444; }
	.code-block { background: #0f172a10; padding: 8px; border-radius: 8px; border: 1px solid var(--border); }
	#detail-body { margin-top: 8px; }
	.dimmed { opacity: 0.2 !important; }
	.highlighted { opacity: 1 !important; }
	#search-results {
		position: fixed;
		top: 60px;
		left: 50%;
		transform: translateX(-50%);
		width: 600px;
		max-width: calc(100vw - 40px);
		max-height: 400px;
		background: var(--panel);
		border: 1px solid var(--border);
		border-radius: 8px;
		padding: 0;
		overflow: hidden;
		z-index: 1000;
		box-shadow: 0 4px 12px rgba(0,0,0,0.15);
		display: none;
	}
	#search-results-header {
		padding: 10px 12px;
		border-bottom: 1px solid var(--border);
		background: var(--bg);
		font-size: 13px;
		font-weight: 600;
		color: var(--text);
		cursor: pointer;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}
	#search-results-header:hover {
		background: var(--panel);
	}
	#search-results-list {
		max-height: 350px;
		overflow-y: auto;
		padding: 8px;
	}
	#search-results h3 {
		margin: 0 0 8px 0;
		font-size: 14px;
		color: var(--text);
	}
	.search-result-item {
		padding: 8px;
		margin: 4px 0;
		border-radius: 4px;
		cursor: pointer;
		border: 1px solid var(--border);
		background: var(--bg);
		transition: background 0.15s;
	}
	.search-result-item:hover {
		background: var(--link);
		color: white;
	}
	.search-result-type {
		font-size: 11px;
		opacity: 0.7;
		margin-left: 6px;
	}
	.search-result-catalog {
		font-size: 10px;
		font-style: italic;
		opacity: 0.6;
		margin-bottom: 2px;
	}
	.search-result-package {
		font-size: 10px;
		font-style: italic;
		opacity: 0.6;
		margin-bottom: 2px;
	}
	/* Multi-layer filter dropdown styles */
	.filter-dropdown { position: relative; }
	.filter-main-menu {
		display: none;
		position: fixed;
		background: var(--panel);
		border: 1px solid var(--border);
		border-radius: 8px;
		min-width: 200px;
		z-index: 9999;
		box-shadow: 0 6px 24px rgba(2,6,23,0.15);
		padding: 4px 0;
	}
	.filter-category {
		padding: 10px 16px;
		cursor: pointer;
		display: flex;
		justify-content: space-between;
		align-items: center;
		position: relative;
	}
	.filter-category:hover { background: var(--bg); }
	.filter-submenu {
		display: none;
		position: fixed;
		background: var(--panel);
		border: 1px solid var(--border);
		border-radius: 8px;
		padding: 8px;
		max-height: 320px;
		overflow: auto;
		min-width: 280px;
		max-width: 320px;
		z-index: 10000;
		box-shadow: 0 6px 24px rgba(2,6,23,0.15);
	}
	.filter-category:hover .filter-submenu { display: block; }
	/* Export dropdown styles */
	.export-dropdown { position: relative; }
	.export-menu {
		display: none;
		position: fixed;
		background: var(--panel);
		border: 1px solid var(--border);
		border-radius: 8px;
		min-width: 200px;
		max-width: 350px;
		z-index: 9999;
		box-shadow: 0 6px 24px rgba(2,6,23,0.15);
		padding: 4px 0;
	}
	.export-item {
		padding: 10px 16px;
		cursor: pointer;
		white-space: pre-wrap;
		word-break: break-word;
		overflow-wrap: anywhere;
		line-height: 1.4;
		max-width: 100%;
		box-sizing: border-box;
	}
	.export-item:hover { background: var(--bg); }
	/* Footer styles */
	footer {
		background: var(--panel);
		border-top: 1px solid var(--border);
		padding: 6px 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 12.5px;
		max-height: 1cm;
		text-align: center;
		gap: 8px;
	}
	.footer-link { color: var(--accent); text-decoration: none; display: inline-flex; align-items: center; gap: 4px; }
	.footer-link:hover { text-decoration: underline; }
	.footer-separator { color: var(--muted); margin: 0 4px; }
	.footer-motto { font-style: italic; color: var(--muted); }
	@media (max-width: 768px) {
		footer { font-size: 10px; gap: 4px; }
		.footer-separator { margin: 0 2px; }
	}
</style>
</head>
<body data-theme="light">
	<header>
		<div class="header-left">
			<div style="font-weight:600; font-size:16px; white-space:nowrap;">Access Package Documentor</div>
			<div class="stat-pill">Catalogs <strong id="stat-catalogs"></strong></div>
			<div class="stat-pill">Packages <strong id="stat-packages"></strong></div>
			<div class="stat-pill">Policies <strong id="stat-policies"></strong></div>
			<div class="stat-pill">Resources <strong id="stat-resources"></strong></div>
			<div class="stat-pill">Extensions <strong id="stat-extensions"></strong></div>
			<div class="filter-dropdown">
				<button id="filter-dropdown-toggle" style="padding:8px 12px; border-radius:8px; border:1px solid var(--border); background:var(--panel); cursor:pointer;">Filter ▾</button>
				<div id="filter-main-menu" class="filter-main-menu">
					<div class="filter-category" data-category="catalogs">
						<span>Catalogs</span>
						<span>▶</span>
						<div class="filter-submenu" id="catalogs-submenu">
							<label style="display:block; margin-bottom:6px;"><input type="checkbox" id="catalog-select-all" checked /> <strong>All catalogs</strong></label>
							<hr style="border:none; height:1px; background:var(--border); margin:6px 0;" />
							<div id="catalog-options"></div>
						</div>
					</div>
					<div class="filter-category" data-category="packages">
						<span>Access Packages</span>
						<span>▶</span>
						<div class="filter-submenu" id="packages-submenu">
							<label style="display:block; margin-bottom:6px;"><input type="checkbox" id="package-select-all" checked /> <strong>All Access Packages</strong></label>
							<hr style="border:none; height:1px; background:var(--border); margin:6px 0;" />
							<div id="package-options"></div>
						</div>
					</div>
					<div class="filter-category" data-category="resources">
						<span>Resources</span>
						<span>▶</span>
						<div class="filter-submenu" id="resources-submenu">
							<label style="display:block; margin-bottom:6px;"><input type="checkbox" id="resource-select-all" checked /> <strong>All Resources</strong></label>
							<hr style="border:none; height:1px; background:var(--border); margin:6px 0;" />
							<div id="resource-options"></div>
						</div>
					</div>
					<div class="filter-category" data-category="extensions">
						<span>Custom Extensions</span>
						<span>▶</span>
						<div class="filter-submenu" id="extensions-submenu">
							<label style="display:block; margin-bottom:6px;"><input type="checkbox" id="extension-select-all" checked /> <strong>All Custom Extensions</strong></label>
							<hr style="border:none; height:1px; background:var(--border); margin:6px 0;" />
							<div id="extension-options"></div>
						</div>
					</div>
				</div>
			</div>
		</div>
		<div class="header-center" style="position: relative;">
			<input id="search" type="search" placeholder="Search node label..." />
			<div id="search-results">
				<div id="search-results-header">
					<span><span id="result-count">0</span> results</span>
					<span id="search-results-toggle">▼</span>
				</div>
				<div id="search-results-list"></div>
			</div>
		</div>
		<div class="header-right">
			<div class="export-dropdown">
				<button id="export-dropdown-toggle" style="padding:8px 12px; border-radius:8px; border:1px solid var(--border); background:var(--panel); cursor:pointer;">Export ▾</button>
				<div id="export-menu" class="export-menu">
					<div class="export-item" data-format="png">Export PNG</div>
					<div class="export-item" data-format="jpeg">Export JPEG</div>
					<div class="export-item" data-format="json">Export JSON</div>
					<div class="export-item" data-format="markdown">Export MARKDOWN</div>
				</div>
			</div>
			<button id="zoom-in">Zoom In</button>
			<button id="zoom-out">Zoom Out</button>
			<button id="fit">Fit</button>
			<button id="collapse-all">Collapse All</button>
			<button id="expand-all">Expand All</button>
			<button id="rearrange">Rearrange</button>
			<button id="toggle-sod">Show SoD</button>
			<button id="theme-toggle" title="Toggle dark/light theme">🌓</button>
		</div>
	</header>
	<div id="container">
		<div id="cy-wrapper">
			<div id="cy"></div>
			<div id="cy-watermark">Access Package Documentor</div>
		</div>
		<aside id="details" class="collapsed">
			<button id="details-toggle" title="Toggle details">▶</button>
			<h3 id="detail-title">Select a node</h3>
			<div id="detail-body" class="small">Click any node to see details.</div>
		</aside>
	</div>

	<script src="https://unpkg.com/cytoscape@3.30.2/dist/cytoscape.min.js"></script>
	<script src="https://unpkg.com/dagre@0.8.5/dist/dagre.min.js"></script>
	<script src="https://unpkg.com/cytoscape-dagre@2.5.0/cytoscape-dagre.js"></script>
	<script>
	(function() {
		function safeParse(jsonText) {
			try { return JSON.parse(jsonText); } catch (err) { return null; }
		}

		var b64 = '__DATA_B64__';
		var decoded = '';
		// Default zoom on initial load (tunable)
		var DEFAULT_ZOOM = 0.9;
		try {
			// UTF-8 aware base64 decode: convert to bytes then decode with TextDecoder when available
			var bytes = Uint8Array.from(atob(b64), function(c) { return c.charCodeAt(0); });
			if (typeof TextDecoder !== 'undefined') {
				decoded = new TextDecoder('utf-8').decode(bytes);
			} else {
				// Fallback for older hosts
				decoded = decodeURIComponent(escape(atob(b64)));
			}
		} catch (e) {
			decoded = '{}'; console.error('Base64 decode failed', e);
		}
		var data = safeParse(decoded) || { nodes: [], edges: [], stats: { CatalogCount: 0, PackageCount: 0, PolicyCount: 0, ResourceCount: 0 } };

		var prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
		var themePref = '__THEME__';
		var initialTheme = themePref === 'Auto' ? (prefersDark ? 'dark' : 'light') : themePref.toLowerCase();
		document.body.setAttribute('data-theme', initialTheme);

		var themeToggle = document.getElementById('theme-toggle');
		function updateThemeIcon() {
			var isDark = document.body.getAttribute('data-theme') === 'dark';
			themeToggle.textContent = isDark ? '☀️' : '🌙';
		}
		updateThemeIcon();
		themeToggle.addEventListener('click', function() {
			var current = document.body.getAttribute('data-theme');
			document.body.setAttribute('data-theme', current === 'dark' ? 'light' : 'dark');
			updateThemeIcon();
		});

		document.getElementById('stat-catalogs').textContent = data.stats.CatalogCount || 0;
		document.getElementById('stat-packages').textContent = data.stats.PackageCount || 0;
		document.getElementById('stat-policies').textContent = data.stats.PolicyCount || 0;
		document.getElementById('stat-resources').textContent = data.stats.ResourceCount || 0;
		document.getElementById('stat-extensions').textContent = data.stats.ExtensionCount || 0;

		function htmlEscape(str) {
			return String(str)
				.replace(/&/g, '&amp;')
				.replace(/</g, '&lt;')
				.replace(/>/g, '&gt;')
				.replace(/"/g, '&quot;')
				.replace(/'/g, '&#39;');
		}

		// Parse ISO 8601 duration (e.g., "P14D" = 14 days, "PT7H" = 7 hours)
		function parseISO8601Duration(duration) {
			if (!duration || typeof duration !== 'string') return null;
			var match = duration.match(/^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
			if (!match) return null;
			var days = parseInt(match[1]) || 0;
			var hours = parseInt(match[2]) || 0;
			var minutes = parseInt(match[3]) || 0;
			var seconds = parseInt(match[4]) || 0;
			return days + (hours / 24) + (minutes / 1440) + (seconds / 86400);
		}

		function renderValue(v, depth) {
			var maxDepth = 5; // Increased max depth
			if (v === null || v === undefined) return '—';
			if (typeof v === 'boolean') return v ? '<span class="badge">Yes</span>' : '<span class="badge bad">No</span>';
			if (typeof v === 'number') return v.toString();
			if (typeof v === 'string') return htmlEscape(v);
			if (depth >= maxDepth) return '<span class="small">Complex data...</span>';

			if (Array.isArray(v)) {
				if (v.length === 0) return '<span class="small">Empty list</span>';
				// Check if all items are approver-like objects
				var hasOdataType = v.length > 0 && v[0] && typeof v[0] === 'object' && v[0]['@odata.type'];
				if (hasOdataType && v[0]['@odata.type'].indexOf('microsoft.graph') !== -1) {
					return formatApprovers(v);
				}
				return '<ul>' + v.map(function(item) { return '<li>' + renderValue(item, depth + 1) + '</li>'; }).join('') + '</ul>';
			}
			if (typeof v === 'object') {
				// Check if this is an approver object
				if (v['@odata.type'] && v['@odata.type'].indexOf('microsoft.graph') !== -1) {
					return formatApprover(v);
				}
				var keys = Object.keys(v).filter(function(k) { return k !== '@odata.type'; });
				if (keys.length === 0) return '<span class="small">Empty</span>';
				// Format as key-value pairs with better styling
				return '<div style="padding-left:10px;">' + keys.map(function(k) {
					var label = k.replace(/([A-Z])/g, ' $1').replace(/^./, function(str){ return str.toUpperCase(); });
					return '<div style="margin:4px 0;"><strong>' + htmlEscape(label) + ':</strong> ' + renderValue(v[k], depth + 1) + '</div>';
				}).join('') + '</div>';
			}
			return htmlEscape(String(v));
		}

		function prettyValue(v) { return renderValue(v, 0); }

		// Helper to translate #EXT# guest emails back to original format
		function translateGuestEmail(upn) {
			if (!upn || typeof upn !== 'string') return upn;
			// Match pattern: username_domain#EXT#@tenant.onmicrosoft.com
			var extMatch = upn.match(/^(.+)_(.+)#EXT#@.+$/);
			if (extMatch) {
				// Reconstruct as username@domain
				return extMatch[1] + '@' + extMatch[2].replace(/_/g, '.');
			}
			return upn;
		}

		// Helper to format approver objects for better readability
		function formatApprover(approver) {
			if (!approver || typeof approver !== 'object') return htmlEscape(String(approver));
			var type = approver['@odata.type'] || '';
			
			// Check sponsor types FIRST to avoid double-tagging with User badge
			if (type === '#microsoft.graph.internalSponsors') {
				return '<span class="badge">Sponsor</span> (Internal)';
			}
			else if (type === '#microsoft.graph.externalSponsors') {
				return '<span class="badge">Sponsor</span> (External)';
			}
			else if (type === '#microsoft.graph.targetUserSponsors') {
				return '<span class="badge">Sponsor</span>';
			}
			else if (type === '#microsoft.graph.requestorManager') {
				var level = approver.managerLevel || 1;
				return '<span class="badge">Manager</span> (Level ' + level + ')';
			}
			else if (type === '#microsoft.graph.singleUser') {
				// Try multiple fallbacks for user display
				var display = approver.displayName || approver.userPrincipalName || approver.id || 'User';
				var upn = approver.userPrincipalName || '';
				// Translate guest email if needed
				var email = translateGuestEmail(upn);
				if (approver.displayName && upn) {
					return '<span class="badge">User</span> ' + htmlEscape(approver.displayName + ' (' + email + ')');
				}
				return '<span class="badge">User</span> ' + htmlEscape(display);
			}
			else if (type === '#microsoft.graph.groupMembers') {
				var groupDesc = approver.description || '';
				if (approver.groupId) {
					return '<span class="badge">Group</span> ' + htmlEscape(groupDesc || approver.groupId);
				}
				return '<span class="badge">Group members</span>';
			}
			else if (type === '#microsoft.graph.attributeRuleMembers') {
				var rule = approver.membershipRule || approver.filter || '';
				if (rule) {
					return '<span class="badge">Attribute rule</span><br><code style="font-size:11px;">' + htmlEscape(rule) + '</code>';
				}
				return '<span class="badge">Attribute rule members</span>';
			}
			
			// Fallback: show available keys
			var keys = Object.keys(approver).filter(function(k) { return k !== '@odata.type' && approver[k] !== null && approver[k] !== undefined; });
			if (keys.length > 0) {
				var parts = keys.map(function(k) { return k + ': ' + String(approver[k]); });
				return htmlEscape(parts.join(', '));
			}
			
			return htmlEscape(JSON.stringify(approver));
		}

		function formatApprovers(approvers, prefix) {
			if (!Array.isArray(approvers) || approvers.length === 0) return '—';
			prefix = prefix || '';
			// Filter out null results from formatApprover (like targetUserSponsors)
			var formatted = approvers.map(function(a) { 
				var result = formatApprover(a);
				if (result === null) return null;
				return '<li>' + (prefix ? '<span style="font-family:monospace;color:#64748b;margin-right:4px;">' + htmlEscape(prefix) + '</span>' : '') + result + '</li>';
			}).filter(function(item) { return item !== null; });
			if (formatted.length === 0) return '—';
			return '<ul>' + formatted.join('') + '</ul>';
		}
		
		// Helper to get catalog name for any node type
		function getCatalogName(node) {
			if (!node || !node.data) return '';
			
			var nodeType = node.data('type');
			
			// For catalog nodes, return their own label
			if (nodeType === 'catalog') {
				return htmlEscape(node.data('label') || '');
			}
			
			// For orphaned nodes, check payload for catalogId and lookup catalog
			if (nodeType === 'orphaned-group' || nodeType === 'orphaned-resource') {
				var payload = node.data('payload');
				if (payload && payload.catalogId) {
					var catalogNode = cy.getElementById('cat-' + payload.catalogId);
					if (catalogNode.length) {
						return htmlEscape(catalogNode.data('label') || '');
					}
				}
			}
			
			// For package nodes, get catalog from payload
			if (nodeType === 'package') {
				var payload = node.data('payload');
				if (payload && payload.catalog) {
					return htmlEscape(payload.catalog);
				}
			}
			
			// For other types (policy, resource, approval-stage), traverse to package then get catalog
			var packageNode = node.predecessors('node[type="package"]').first();
			if (packageNode.length) {
				var pkgPayload = packageNode.data('payload');
				if (pkgPayload && pkgPayload.catalog) {
					return htmlEscape(pkgPayload.catalog);
				}
			}
			
			return '';
		}
		
		// Helper to get package name for any node type
		function getPackageName(node) {
			if (!node || !node.data) return '';
			
			var nodeType = node.data('type');
			
			// For catalog nodes, no package
			if (nodeType === 'catalog' || nodeType === 'orphaned-group' || nodeType === 'orphaned-resource') {
				return '';
			}
			
			// For package nodes, return their own label
			if (nodeType === 'package') {
				return htmlEscape(node.data('label') || '');
			}
			
			// For other types, traverse to find parent package
			var packageNode = node.predecessors('node[type="package"]').first();
			if (packageNode.length) {
				return htmlEscape(packageNode.data('label') || '');
			}
			
			return '';
		}
		
		// Helper to format allowed target scope from camelCase to human-readable
		function formatTargetScope(scope) {
			if (!scope) return '—';
			var scopeStr = String(scope);
			
			// Map common scope values to readable text
			var scopeMap = {
				'allDirectoryUsers': 'All directory users',
				'allMemberUsers': 'All member users',
				'allConfiguredConnectedOrganizationUsers': 'All configured connected organization users',
				'allExistingConnectedOrganizationUsers': 'All existing connected organization users',
				'allExternalUsers': 'All external users',
				'specificDirectoryUsers': 'Specific users',
				'specificConnectedOrganizationUsers': 'Specific connected organization users',
				'noSubjects': 'No subjects'
			};
			
			return scopeMap[scopeStr] || scopeStr;
		}

		// Helper to format custom extension stage codes to portal-friendly labels
		function formatExtensionStage(stage) {
			if (!stage) return 'Unknown';
			switch (String(stage)) {
				case 'requestCreated':
					return 'Request is created';
				case 'requestApproved':
					return 'Request is approved';
				case 'assignmentGranted':
				case 'assignmentRequestGranted':
					return 'Assignment is granted';
				case 'assignmentRemoved':
					return 'Assignment is removed';
				case 'assignmentAboutToExpireIn14Days':
					return 'Assignment is about to expire in 14 days';
				case 'assignmentAboutToExpireIn1Day':
					return 'Assignment is about to expire in 1 day';
				default:
					// Try friendly spacing for unknown camelCase
					return String(stage).replace(/([A-Z])/g, ' $1').replace(/^./, function(s){ return s.toUpperCase(); });
			}
		}
		
		// Helper to format review settings
		function formatReviewSettings(settings) {
			if (!settings || typeof settings !== 'object') return '—';
			
				// Build summary
			var summary = [];
			if (settings.isEnabled !== undefined) {
				summary.push((settings.isEnabled ? '<span class="badge">Enabled</span>' : '<span class="badge bad">Disabled</span>'));
			}
			if (settings.isRecommendationEnabled !== undefined || settings.isAccessRecommendationEnabled !== undefined) {
				var isRec = settings.isRecommendationEnabled || settings.isAccessRecommendationEnabled;
				summary.push('Recommendations: ' + (isRec ? '<span class="badge">Yes</span>' : '<span class="badge bad">No</span>'));
			}
			
			// Build full details
			var html = '<div style="padding-left:10px;">';
			if (settings.isEnabled !== undefined) {
				html += '<div><strong>Enabled:</strong> ' + (settings.isEnabled ? '<span class="badge">Yes</span>' : '<span class="badge bad">No</span>') + '</div>';
			}
			if (settings.expirationBehavior || settings.accessReviewTimeoutBehavior) {
				var behavior = settings.expirationBehavior || settings.accessReviewTimeoutBehavior;
				var behaviorMap = {
					'acceptAccessRecommendation': 'Accept access recommendation',
					'keepAccess': 'Keep access',
					'removeAccess': 'Remove access'
				};
				html += '<div><strong>Expiration behavior:</strong> ' + (behaviorMap[behavior] || htmlEscape(behavior)) + '</div>';
			}
			if (settings.isRecommendationEnabled !== undefined || settings.isAccessRecommendationEnabled !== undefined) {
				var isRec = settings.isRecommendationEnabled || settings.isAccessRecommendationEnabled;
				html += '<div><strong>Recommendations:</strong> ' + (isRec ? '<span class="badge">Yes</span>' : '<span class="badge bad">No</span>') + '</div>';
			}
			if (settings.isReviewerJustificationRequired !== undefined) {
				html += '<div><strong>Reviewer justification required:</strong> ' + (settings.isReviewerJustificationRequired ? '<span class="badge">Yes</span>' : '<span class="badge bad">No</span>') + '</div>';
			}
			if (settings.isSelfReview !== undefined) {
				html += '<div><strong>Self review:</strong> ' + (settings.isSelfReview ? '<span class="badge">Yes</span>' : '<span class="badge bad">No</span>') + '</div>';
			}
			if (settings.recurrenceType) {
				html += '<div><strong>Recurrence:</strong> ' + htmlEscape(settings.recurrenceType) + '</div>';
			}
			if (settings.durationInDays) {
				html += '<div><strong>Duration:</strong> ' + settings.durationInDays + ' days</div>';
			}
			// Schedule with recurrence
			if (settings.schedule && typeof settings.schedule === 'object') {
				var sched = settings.schedule;
				if (sched.startDateTime) {
					html += '<div><strong>Start date:</strong> ' + htmlEscape(sched.startDateTime) + '</div>';
				}
				if (sched.expiration) {
					html += '<div><strong>Review duration:</strong> ' + formatExpiration(sched.expiration) + '</div>';
				}
				if (sched.recurrence && sched.recurrence.pattern) {
					var pattern = sched.recurrence.pattern;
					var recText = (pattern.type || 'Unknown').charAt(0).toUpperCase() + (pattern.type || 'unknown').slice(1);
					if (pattern.interval) recText += ' (every ' + pattern.interval + ')';
					html += '<div><strong>Recurrence pattern:</strong> ' + htmlEscape(recText) + '</div>';
				}
			}
			if (settings.reviewers && Array.isArray(settings.reviewers)) {
				html += '<div><strong>Reviewers:</strong> ' + formatApprovers(settings.reviewers) + '</div>';
			}
			if (settings.primaryReviewers && Array.isArray(settings.primaryReviewers)) {
				if (settings.primaryReviewers.length > 0) {
					html += '<div><strong>Primary reviewers:</strong> ' + formatApprovers(settings.primaryReviewers) + '</div>';
				} else {
					html += '<div><strong>Primary reviewers:</strong> <span class="small">None specified</span></div>';
				}
			}
			if (settings.fallbackReviewers && Array.isArray(settings.fallbackReviewers)) {
				if (settings.fallbackReviewers.length > 0) {
					html += '<div><strong>Fallback reviewers:</strong> ' + formatApprovers(settings.fallbackReviewers) + '</div>';
				} else {
					html += '<div><strong>Fallback reviewers:</strong> <span class="small">None specified</span></div>';
				}
			}
			html += '</div>';
			
			// Return with expandable details
				var summaryText = summary.join(' | ') || 'View details';
			return '<details><summary style="cursor:pointer;color:var(--accent);">' + summaryText + '</summary>' + html + '</details>';
		}
		
		// Helper to format notification settings
		function formatNotificationSettings(settings) {
			if (!settings || typeof settings !== 'object') return '—';
			var html = '<div style="padding-left:10px;">';
			
			var keys = Object.keys(settings).filter(function(k) { return k !== '@odata.type'; });
			keys.forEach(function(k) {
				var label = k.replace(/([A-Z])/g, ' $1').replace(/^./, function(str){ return str.toUpperCase(); });
				var value = settings[k];
				if (typeof value === 'boolean') {
					html += '<div><strong>' + htmlEscape(label) + ':</strong> ' + (value ? '<span class="badge">Yes</span>' : '<span class="badge bad">No</span>') + '</div>';
				} else if (value !== null && value !== undefined) {
					html += '<div><strong>' + htmlEscape(label) + ':</strong> ' + renderValue(value, 1) + '</div>';
				}
			});
			
			html += '</div>';
			return html;
		}
		
		// Helper to format expiration settings
		function formatExpiration(expiration) {
			if (!expiration || typeof expiration !== 'object') return '—';
			var html = '<div style="padding-left:10px;">';
			
			if (expiration.type) {
				var typeMap = {
					'afterDuration': 'After duration',
					'afterDateTime': 'After date/time',
					'noExpiration': 'No expiration'
				};
				html += '<div><strong>Type:</strong> ' + (typeMap[expiration.type] || htmlEscape(expiration.type)) + '</div>';
			}
			if (expiration.duration) {
				// Parse ISO 8601 duration (e.g., PT5H, P3D)
				var duration = expiration.duration;
				var readable = duration.replace(/^PT/, '').replace(/^P/, '')
					.replace(/([0-9]+)H/, '$1 hours ')
					.replace(/([0-9]+)M/, '$1 minutes ')
					.replace(/([0-9]+)D/, '$1 days ')
					.replace(/([0-9]+)W/, '$1 weeks ')
					.trim();
				html += '<div><strong>Duration:</strong> ' + htmlEscape(readable || duration) + '</div>';
			}
			if (expiration.endDateTime) {
				html += '<div><strong>End date:</strong> ' + htmlEscape(expiration.endDateTime) + '</div>';
			}
			
			html += '</div>';
			return html;
		}
		
		// Helper to format automatic request settings
		function formatAutomaticRequestSettings(settings) {
			if (!settings || typeof settings !== 'object') return '<span class="badge bad">Disabled</span>';
			var html = '<div style="padding-left:10px;">';
			
			// Handle different assignment types with fallback when @odata.type is missing
			var odataType = settings['@odata.type'] || '';
			if (odataType === '#microsoft.graph.attributeRuleMembers' || settings.membershipRule) {
				html += '<div><strong>Type:</strong> Attribute rule members (dynamic assignment)</div>';
				if (settings.description) {
					html += '<div><strong>Description:</strong> ' + htmlEscape(settings.description) + '</div>';
				}
				if (settings.membershipRule) {
					html += '<div style="margin-top:4px;"><strong>Membership rule:</strong><br><code style="display:block;background:#0f172a10;padding:8px;border-radius:6px;margin-top:4px;font-size:11px;word-break:break-all;">' + htmlEscape(settings.membershipRule) + '</code></div>';
				}
			} else if (odataType) {
				html += '<div><strong>Type:</strong> ' + htmlEscape(odataType.replace('#microsoft.graph.', '')) + '</div>';
			} else {
				// Fallback when no type is specified
				html += '<div><strong>Type:</strong> Automatic assignment</div>';
			}
			
			if (settings.gracePeriodBeforeAccessRemoval) {
				var grace = settings.gracePeriodBeforeAccessRemoval;
				var readable = grace.replace(/^PT/, '').replace(/^P/, '')
					.replace(/([0-9]+)H/, '$1 hours ')
					.replace(/([0-9]+)M/, '$1 minutes ')
					.replace(/([0-9]+)D/, '$1 days ')
					.trim();
				html += '<div><strong>Grace period before access removal:</strong> ' + htmlEscape(readable || grace) + '</div>';
			}
			if (settings.requestAccessForAllowedTargets !== undefined) {
				html += '<div><strong>Request access for allowed targets:</strong> ' + (settings.requestAccessForAllowedTargets ? '<span class="badge">Yes</span>' : '<span class="badge bad">No</span>') + '</div>';
			}
			if (settings.removeAccessWhenTargetLeavesAllowedTargets !== undefined) {
				html += '<div><strong>Remove access when target leaves allowed targets:</strong> ' + (settings.removeAccessWhenTargetLeavesAllowedTargets ? '<span class="badge">Yes</span>' : '<span class="badge bad">No</span>') + '</div>';
			}
			
			html += '</div>';
			return html;
		}

		function createPayloadHtml(payload) {
			var chips = [];
			Object.keys(payload || {}).forEach(function(k) {
				var v = payload[k];
				if (v === null || v === undefined) return;
				if (Array.isArray(v) && v.length === 0) return;
				chips.push('<div class="detail-chip"><span class="label">' + htmlEscape(k) + '</span><div class="value">' + prettyValue(v) + '</div></div>');
			});
			if (chips.length === 0) {
				return '<span class="small">No additional details.</span>';
			}
			return '<div class="detail-grid">' + chips.join('') + '</div>';
		}

		function renderDetails(nodeData) {
			var type = nodeData.type;
			var p = nodeData.payload || {};
			var chips = [];

			function add(label, value) {
				if (value === undefined) return;
				chips.push('<div class="detail-chip"><span class="label">' + htmlEscape(label) + '</span><div class="value">' + value + '</div></div>');
			}

			if (type === 'policy') {
				var audience = p.audiencePrefix || '—';
				// Remove trailing colon if present
				if (audience.endsWith(':')) audience = audience.slice(0, -1);
				add('Audience', htmlEscape(audience));
				add('Description', htmlEscape(p.description || '—'));
				
				// Format allowed target scope with human-readable text
				var scopeHtml = formatTargetScope(p.allowedTargetScope);
				if ((p.allowedTargetScope === 'specificDirectoryUsers' || p.allowedTargetScope === 'specificConnectedOrganizationUsers') && p.specificAllowedTargets) {
					// Check if specificAllowedTargets is an array and has items
					var targets = Array.isArray(p.specificAllowedTargets) ? p.specificAllowedTargets : [p.specificAllowedTargets];
					if (targets.length > 0) {
						scopeHtml += '<br><details><summary style="cursor:pointer;color:var(--accent);">View specific targets (' + targets.length + ')</summary>' + formatApprovers(targets) + '</details>';
					}
				}
				add('Assigned to', scopeHtml);
				
				// Automatic request settings - only show if configured
				if (p.schedule) add('Schedule', prettyValue(p.schedule));
				
				// Expiration
				if (p.expiration) {
					add('Expiration', formatExpiration(p.expiration));
				}
				
				// Requestor justification - separate field showing Yes/No
				var justRequired = false;
				
				// Check requestApprovalSettings first (most reliable source)
				if (p.requestApprovalSettings && typeof p.requestApprovalSettings === 'object') {
					justRequired = p.requestApprovalSettings.isRequestorJustificationRequired === true;
				}
				// Fallback to legacy property
				else if (typeof p.requestorJustification === 'boolean') {
					justRequired = p.requestorJustification;
				} else if (p.requestorJustification && typeof p.requestorJustification === 'object') {
					justRequired = p.requestorJustification.isRequired || p.requestorJustification.required || p.requestorJustification.isRequestorJustificationRequired;
				}
				
				add('Requestor justification required', justRequired ? '<span class="badge">Yes</span>' : '<span class="badge bad">No</span>');
				
				// Requestor information (questions) - expandable with full details
				var questions = p.questions || [];
				
				if (Array.isArray(questions) && questions.length > 0) {
				// Build summary
				var summaryText = questions.length + ' question' + (questions.length !== 1 ? 's' : '');
				
				// Build detailed view
				var detailsHtml = '<div style="padding-left:10px;"><ul style="margin-top:4px;">';
				questions.forEach(function(q) {
					// Handle text as object or string
					var qText = q.text;
					if (typeof qText === 'object' && qText !== null) {
						// Extract from text object (defaultText or localizedTexts)
						qText = qText.defaultText || qText.text || '';
						if (!qText && Array.isArray(qText.localizedTexts) && qText.localizedTexts.length > 0) {
							qText = qText.localizedTexts[0].text || qText.localizedTexts[0].value || '';
						}
					}
					qText = qText || 'Untitled question';
					
					var qType = '';
					if (q['@odata.type']) {
						var odataType = q['@odata.type'];
						if (odataType.indexOf('TextInput') !== -1) {
							qType = q.isSingleLineQuestion ? 'Single-line text' : 'Multi-line text';
						} else if (odataType.indexOf('MultipleChoice') !== -1) {
							qType = 'Multiple choice';
						} else {
							qType = odataType.replace('#microsoft.graph.accessPackage', '').replace('Question', ' question');
						}
					}
					var requiredBadge = q.isRequired ? '<span class="badge">Required</span>' : '<span class="badge bad">Optional</span>';
					var editableBadge = q.isAnswerEditable !== false ? '<span class="badge">Editable</span>' : '<span class="badge bad">Read-only</span>';
					
					detailsHtml += '<li style="margin-bottom:8px;"><strong>' + htmlEscape(qText) + '</strong><br>';
					detailsHtml += '<div style="margin-top:4px;">' + requiredBadge + ' ' + editableBadge;
					if (qType) detailsHtml += ' | <small>' + htmlEscape(qType) + '</small>';
					detailsHtml += '</div>';
					
					// Add additional question details
					if (q.regexPattern) {
						detailsHtml += '<div style="margin-top:4px;"><small><strong>Pattern:</strong> <code>' + htmlEscape(q.regexPattern) + '</code></small></div>';
					}
					if (q.choices && Array.isArray(q.choices) && q.choices.length > 0) {
						detailsHtml += '<div style="margin-top:4px;"><small><strong>Choices:</strong> ';
						var choiceTexts = q.choices.map(function(c) {
							// Handle choice text as object or string
							var choiceText = c.displayValue || c.actualValue;
							if (!choiceText && c.text) {
								if (typeof c.text === 'object' && c.text !== null) {
									choiceText = c.text.defaultText || c.text.text || '';
									if (!choiceText && Array.isArray(c.text.localizedTexts) && c.text.localizedTexts.length > 0) {
										choiceText = c.text.localizedTexts[0].text || c.text.localizedTexts[0].value || '';
									}
								} else {
									choiceText = c.text;
								}
							}
							return htmlEscape(choiceText || 'Choice');
						});
						detailsHtml += choiceTexts.join(', ') + '</small></div>';
					}
					
					detailsHtml += '</li>';
				});
				detailsHtml += '</ul></div>';
				
				// Return collapsible with summary
				var infoHtml = '<details><summary style="cursor:pointer;color:var(--accent);">' + summaryText + '</summary>' + detailsHtml + '</details>';
				add('Requestor information (questions)', infoHtml);
			} else {
				add('Requestor information (questions)', '<span class="badge bad">None</span>');
			}
			
			var rs = p.requestorSettings || {};
			add('Self add access', prettyValue(rs.enableTargetsToSelfAddAccess));
			add('Self remove access', prettyValue(rs.enableTargetsToSelfRemoveAccess));
			add('Self update access', prettyValue(rs.enableTargetsToSelfUpdateAccess));
			add('On-behalf add access', prettyValue(rs.enableOnBehalfRequestorsToAddAccess));
			add('On-behalf update access', prettyValue(rs.enableOnBehalfRequestorsToUpdateAccess));
			add('On-behalf remove access', prettyValue(rs.enableOnBehalfRequestorsToRemoveAccess));
			if (Array.isArray(rs.onBehalfRequestors)) {
				var readable = rs.onBehalfRequestors.map(function(item) {
					if (item && typeof item === 'object' && item['@odata.type'] === '#microsoft.graph.targetManager') {
						return 'Managers up to level ' + (item.managerLevel ?? 'N/A');
					}
					return JSON.stringify(item);
				});
				add('On-behalf requestors', htmlEscape(readable.join(', ')));
			}
			if (p.verificationSettings) add('Verifiable credentials', prettyValue(p.verificationSettings));
			if (p.reviewSettings) add('Access review settings', formatReviewSettings(p.reviewSettings));
			if (p.notificationSettings) add('Notification settings', formatNotificationSettings(p.notificationSettings));
			if (p.assignmentRequirements) add('Assignment requirements', prettyValue(p.assignmentRequirements));
		}
		else if (type === 'resource') {
				add('Resource type', htmlEscape(p.typeLabel || p.type || '—'));
				add('Origin system', htmlEscape(p.originSystem || '—'));
				add('Origin ID', htmlEscape(p.originId || '—'));
				add('Resource ID', htmlEscape(p.resourceId || '—'));
				add('Role', htmlEscape(p.roleDisplay || '—'));
				add('Role ID', htmlEscape(p.roleId || '—'));
				add('Assignment type', htmlEscape(p.assignmentType || '—'));
				add('Scope', htmlEscape(p.scope || '—'));
			}
			else if (type === 'orphaned-resource') {
				add('Resource type', htmlEscape(p.typeLabel || p.type || '—'));
				add('Origin system', htmlEscape(p.originSystem || '—'));
				add('Origin ID', htmlEscape(p.originId || '—'));
				add('Resource ID', htmlEscape(p.resourceId || '—'));
				add('Status', '<span class="badge bad">Orphaned - Not assigned to any active access package</span>');
			}
			else if (type === 'orphaned-group') {
				add('Catalog ID', htmlEscape(p.catalogId || '—'));
				add('Orphaned resource count', htmlEscape(String(p.count ?? 0)));
				add('Description', '<span class="small">Resources in this catalog not assigned to any active access package</span>');
			}
			else if (type === 'package') {
				add('Catalog', htmlEscape(p.catalog || '—'));
				add('Description', htmlEscape(p.description || '—'));
				if (p.state) add('State', htmlEscape(p.state));
				if (p.createdDateTime) add('Created', htmlEscape(p.createdDateTime));
				if (p.modifiedDateTime) add('Modified', htmlEscape(p.modifiedDateTime));
			}
			else if (type === 'catalog') {
				add('Description', htmlEscape(p.description || '—'));
				if (p.catalogType) add('Type', htmlEscape(p.catalogType));
				if (p.state) add('State', htmlEscape(p.state));
				if (p.isExternallyVisible !== undefined) add('Externally visible', prettyValue(p.isExternallyVisible));
			}
			else if (type === 'policy-group') {
				add('Access Package', htmlEscape(p.packageName || '—'));
				add('Policy count', htmlEscape(String(p.count ?? 0)));
			}
			else if (type === 'resource-group') {
				add('Access Package', htmlEscape(p.packageName || '—'));
				add('Resource count', htmlEscape(String(p.count ?? 0)));
			}
			else if (type === 'approval-stage') {
				// Handle timeout - parse ISO 8601 duration if needed
				var timeoutValue = p.approvalStageTimeOutInDays;
				if (timeoutValue !== undefined && timeoutValue !== null) {
					if (typeof timeoutValue === 'string' && timeoutValue.startsWith('P')) {
						// Parse ISO 8601 duration
						var parsedTimeout = parseISO8601Duration(timeoutValue);
						if (parsedTimeout !== null) {
							add('Timeout', htmlEscape(parsedTimeout + ' days'));
						}
					} else {
						add('Timeout', htmlEscape(timeoutValue + ' days'));
					}
				}
				if (p.isApproverJustificationRequired !== undefined) add('Justification required', prettyValue(p.isApproverJustificationRequired));
				if (p.isEscalationEnabled !== undefined) add('Alternative enabled', prettyValue(p.isEscalationEnabled));
				// Show alternative time only when escalation is enabled
				if (p.isEscalationEnabled) {
					var escalationDays = p.escalationTimeInDays;
					if (escalationDays === undefined || escalationDays === null) {
						// Try to calculate from minutes
						var escalationMinutes = p.escalationTimeInMinutes;
						if (escalationMinutes !== undefined && escalationMinutes !== null) {
							escalationDays = Math.round((escalationMinutes / 1440) * 100) / 100;
						} else if (p.escalationTime) {
							// Try parsing ISO 8601 duration (e.g., "P13D")
							var parsed = parseISO8601Duration(p.escalationTime);
							if (parsed !== null) escalationDays = parsed;
						} else if (p.durationBeforeEscalation) {
							// Try parsing durationBeforeEscalation
							var parsed2 = parseISO8601Duration(p.durationBeforeEscalation);
							if (parsed2 !== null) escalationDays = parsed2;
						}
					}
					// Show escalation time if we have a numeric value
					if (escalationDays !== undefined && escalationDays !== null && !isNaN(escalationDays) && escalationDays >= 0) {
						add('Alternative time', htmlEscape(escalationDays + ' days'));
					}
				}
				
				// Format primary approvers with displayName + UPN
				if (p.primaryApprovers && Array.isArray(p.primaryApprovers)) {
					add('Approvers', formatApprovers(p.primaryApprovers));
				} else if (p.primaryApprovers) {
					add('Approvers', formatApprover(p.primaryApprovers) || prettyValue(p.primaryApprovers));
				}
				
				// Format backup/fallback approvers
				if (p.backupApprovers && Array.isArray(p.backupApprovers)) {
					add('Fallback approvers', formatApprovers(p.backupApprovers));
				} else if (p.backupApprovers) {
					add('Fallback approvers', formatApprover(p.backupApprovers) || prettyValue(p.backupApprovers));
				}
				
				// Format alternative (escalation) approvers
				if (p.escalationApprovers && Array.isArray(p.escalationApprovers)) {
					add('Alternative approvers', formatApprovers(p.escalationApprovers));
				} else if (p.escalationApprovers) {
					add('Alternative approvers', formatApprover(p.escalationApprovers) || prettyValue(p.escalationApprovers));
				}
			}
			else if (type === 'custom-extension') {
				// Support full customExtension payload (server provides p.customExtension when available)
				var ext = p.customExtension || p;
				if (p.stage) add('Stage', htmlEscape(formatExtensionStage(p.stage)));
				if (ext.extensionType) add('Extension type', htmlEscape(ext.extensionType));
				if (ext.displayName) add('Display name', htmlEscape(ext.displayName));
				if (ext.endpointUrl) add('Endpoint URL', htmlEscape(ext.endpointUrl));
				if (ext.clientConfiguration) add('Client configuration', prettyValue(ext.clientConfiguration));
			}
			else {
				return createPayloadHtml(p);
			}

			if (chips.length === 0) return '<span class="small">No additional details.</span>';
			return '<div class="detail-grid">' + chips.join('') + '</div>';
		}

		var iconByType = {
			catalog: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%230ea5e9"><path d="M4 6.5A2.5 2.5 0 0 1 6.5 4h5a2.5 2.5 0 0 1 2.45 2h3.55A2.5 2.5 0 0 1 20 8.5v9A2.5 2.5 0 0 1 17.5 20h-11A2.5 2.5 0 0 1 4 17.5v-11Z"/></svg>',
			package: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%2338bdf8"><path d="M4.5 6.75 12 3l7.5 3.75v7.5L12 18l-7.5-3.75v-7.5Zm7.5 1.5 6-3M12 8.25 6 5.25m6 3v9" stroke="%23ffffff" stroke-width="1.2" fill="none"/></svg>',
			policy: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%23a855f7"><path d="M7 4.5h10v15H7v-15Z" stroke="%23ffffff" stroke-width="1.2" fill="none"/><path d="M9.5 8.5h5M9.5 11.5h5M9.5 14.5h3" stroke="%23ffffff" stroke-width="1.2"/></svg>',
			resourceDefault: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%2322c55e"><path d="M7 7a5 5 0 0 1 10 0c0 2.5-2 4.5-5 7.5-3-3-5-5-5-7.5Z" stroke="%23ffffff" stroke-width="1.2" fill="none"/><circle cx="12" cy="7" r="1.8" fill="%23ffffff"/></svg>',
			resourceGroup: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%2310b981"><path d="M6 7.5A1.5 1.5 0 0 1 7.5 6h9A1.5 1.5 0 0 1 18 7.5v9A1.5 1.5 0 0 1 16.5 18h-9A1.5 1.5 0 0 1 6 16.5v-9Z" stroke="%23ffffff" stroke-width="1.2" fill="none"/><path d="M9 10h6M9 13h6" stroke="%23ffffff" stroke-width="1.2"/></svg>',
			resourceApp: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%233b82f6"><rect x="5" y="5" width="14" height="14" rx="3" stroke="%23ffffff" stroke-width="1.2" fill="none"/><path d="M9 12h6M12 9v6" stroke="%23ffffff" stroke-width="1.2"/></svg>',
			resourceSite: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%2306b6d4"><rect x="4.5" y="6" width="15" height="12" rx="2" stroke="%23ffffff" stroke-width="1.2" fill="none"/><path d="M4.5 9.5h15" stroke="%23ffffff" stroke-width="1.2"/><path d="M8 12.5h4M8 15.5h6" stroke="%23ffffff" stroke-width="1.2"/></svg>',
			resourceRole: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%23f59e0b"><circle cx="12" cy="8" r="3" stroke="%23ffffff" stroke-width="1.2" fill="none"/><path d="M6 20c0-3.5 2.5-6 6-6s6 2.5 6 6" stroke="%23ffffff" stroke-width="1.2" fill="none"/></svg>',
			resourceAPI: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%238b5cf6"><path d="M7 8l-3 4 3 4M17 8l3 4-3 4M14 4l-4 16" stroke="%23ffffff" stroke-width="1.5" fill="none" stroke-linecap="round"/></svg>',
			"approval-stage": 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%23f59e0b"><path d="M4 12.5 9.5 18 20 6.5" stroke="%23ffffff" stroke-width="1.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>',
			"custom-extension": 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%23ec4899"><path d="M13.5 3.5 6 13h5l-1.5 7.5L18 11h-5l.5-7.5Z" stroke="%23ffffff" stroke-width="1.2" fill="none" stroke-linejoin="round"/></svg>',
			"orphaned-group": 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%23f59e0b"><path d="M12 2L2 7v10c0 5.5 4.5 7 10 7s10-1.5 10-7V7L12 2Z" stroke="%23ffffff" stroke-width="1.2" fill="none"/><path d="M12 9v3M12 15h.01" stroke="%23ffffff" stroke-width="1.5" stroke-linecap="round"/></svg>',
			"orphaned-resource": 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%23fbbf24"><path d="M12 2L2 7v10c0 5.5 4.5 7 10 7s10-1.5 10-7V7L12 2Z" stroke="%23ffffff" stroke-width="1.2" fill="none"/><circle cx="12" cy="10" r="2" fill="%23ffffff"/></svg>'
		};

		function iconForResource(system, typeLabel) {
			var s = (system || '').toLowerCase();
			var t = (typeLabel || '').toLowerCase();
			if (s.includes('group') || t.includes('group') || t.includes('team')) return iconByType.resourceGroup;
			if (s.includes('application') || s.includes('app') || t.includes('app')) return iconByType.resourceApp;
			if (s.includes('sharepoint') || s.includes('spo') || t.includes('sharepoint') || t.includes('site')) return iconByType.resourceSite;
			if (s.includes('role') || t.includes('role')) return iconByType.resourceRole;
			if (s.includes('api') || t.includes('api') || t.includes('permission')) return iconByType.resourceAPI;
			return iconByType.resourceDefault;
		}

		var elements = [];
		(data.nodes || []).forEach(function(n) {
			var payload = n.data || n.payload || {};
			var icon = iconByType[n.type] || iconByType.resourceDefault;
			var typeLabel = payload.typeLabel || '';
			var bgColor = null;
			
			if (n.type === 'resource' || n.type === 'orphaned-resource') {
				icon = iconForResource(payload.originSystem, typeLabel);
				// Set color based on typeLabel
				var tl = typeLabel.toLowerCase();
				if (tl.includes('group') || tl.includes('team')) {
					bgColor = '#10b981';
				} else if (tl.includes('app')) {
					bgColor = '#3b82f6';
				} else if (tl.includes('sharepoint') || tl.includes('site')) {
					bgColor = '#06b6d4';
				} else if (tl.includes('role')) {
					bgColor = '#f59e0b';
				} else if (tl.includes('api') || tl.includes('permission')) {
					bgColor = '#8b5cf6';
				} else {
					bgColor = '#22c55e';
				}
			}
			
			elements.push({ 
				data: { id: n.id, label: n.label, type: n.type, typeLabel: typeLabel, payload: payload, icon: icon, parent: n.parent, bgColor: bgColor || (n.type === 'catalog' ? '#0ea5e9' : n.type === 'package' ? '#fb7185' : n.type === 'policy' ? '#a855f7' : n.type === 'approval-stage' ? '#facc15' : n.type === 'custom-extension' ? '#e5e7eb' : '#22c55e') } 
			});
		});
		(data.edges || []).forEach(function(e) {
			elements.push({ data: { id: e.id, source: e.source, target: e.target, type: e.type } });
		});

		var roots = (data.nodes || []).filter(function(n) { return n.type === 'catalog'; }).map(function(n) { return n.id; });
		if (!roots.length) {
			roots = (data.nodes || []).slice(0, 1).map(function(n) { return n.id; });
		}

		var cy = cytoscape({
			container: document.getElementById('cy'),
			elements: elements,
			// IMPORTANT: Do not run an initial layout on the fully-expanded graph.
			// We collapse first, then compute layout only for currently-visible nodes on expand.
			layout: { name: 'preset' },
			style: [
				{ selector: 'node', style: { 'label': 'data(label)', 'color': '#0f172a', 'text-valign': 'center', 'text-halign': 'center', 'font-size': '8px', 'text-wrap': 'wrap', 'text-max-width': 100, 'width': 105, 'height': 75, 'padding': 8, 'background-color': 'data(bgColor)', 'border-width': 1, 'border-color': '#e5e7eb', 'background-fit': 'contain', 'background-image': 'data(icon)', 'shape': 'round-rectangle', 'badge-color': '#dc3545', 'badge-size': '8px', 'badge-position': 'top-right' } },
				{ selector: 'node.has-sod-conflict', style: { 'border-width': 3, 'border-color': '#dc3545', 'border-style': 'double' } },
				{ selector: 'node[type="catalog"]', style: { 'background-color': '#0ea5e9', 'width': 115, 'height': 85, 'text-max-width': 120 } },
				{ selector: 'node[type="package"]', style: { 'background-color': '#fb7185' } },
				{ selector: 'node[type="policy"]', style: { 'background-color': '#a855f7' } },
				{ selector: 'node[type="policy-group"]', style: { 'background-color': '#00ff00' } },
				{ selector: 'node[type="resource-group"]', style: { 'background-color': '#ff00d8' } },
				{ selector: 'node[type="orphaned-group"]', style: { 'background-color': '#f59e0b', 'width': 90, 'height': 70 } },
				{ selector: 'node[type="orphaned-resource"]', style: { 'border-color': '#f59e0b', 'border-width': 2 } },
				{ selector: 'node[type="resource"]', style: {} },
				{ selector: 'node[type="approval-stage"]', style: { 'background-color': '#facc15' } },
				{ selector: 'node[type="custom-extension"]', style: { 'background-color': '#e5e7eb', 'color': '#111827' } },
				{ selector: 'edge', style: { 'width': 1.4, 'line-color': '#94a3b8', 'target-arrow-color': '#94a3b8', 'target-arrow-shape': 'triangle', 'curve-style': 'bezier' } },
				{ selector: '.hidden', style: { 'display': 'none' } },
				{ selector: '.hidden-by-filter', style: { 'display': 'none' } },
				{ selector: '.collapsed', style: { 'display': 'none' } },
				{ selector: '.dimmed', style: { 'opacity': 0.2 } },
				{ selector: '.highlighted', style: { 'opacity': 1 } },
				{ selector: 'edge[type="sod-conflict"]', style: { 'line-color': '#dc3545', 'line-style': 'dashed', 'target-arrow-color': '#dc3545', 'source-arrow-color': '#dc3545', 'curve-style': 'bezier', 'width': 3, 'label': '⚠️ SoD', 'text-rotation': 'autorotate', 'target-arrow-shape': 'triangle', 'source-arrow-shape': 'triangle', 'font-size': '12px', 'color': '#dc3545' } },
				{ selector: 'edge[type="sod-conflict"].sod-hidden', style: { 'display': 'none' } },
				{ selector: 'edge[type="custom-extension"]', style: { 'line-color': '#059669', 'target-arrow-color': '#059669', 'width': 2 } }
			]
		});

		function runVisibleLayout(triggerNode) {
			var DEBUG_LAYOUT = false;
			var visible = cy.elements().not('.collapsed').not('.hidden').not('.hidden-by-filter');
			var visibleNodes = visible.nodes();
			if (!visibleNodes.length) return;

			// Preserve the user's viewport. Do NOT fit/zoom when expanding/collapsing.
			var prevZoom = cy.zoom();
			var prevPan = { x: cy.pan('x'), y: cy.pan('y') };

			// Store positions of manually moved (pinned) nodes before layout
			var pinnedPositions = {};
			cy.nodes().forEach(function(n) {
				if (n.data('pinned')) {
					pinnedPositions[n.id()] = { x: n.position('x'), y: n.position('y') };
				}
			});

			// Visible catalogs (each catalog is its own tree)
			var visibleCatalogs = cy.nodes('[type="catalog"]').not('.collapsed').not('.hidden').not('.hidden-by-filter');
			if (!visibleCatalogs.length) return;

			// If a node triggered this (expand/collapse), only re-layout that one catalog tree.
			// This keeps things stable and follows the “parent + sibling” principle.
			var catalogsToLayout = visibleCatalogs;
			if (triggerNode && triggerNode.length) {
				var cat = triggerNode;
				if (cat.data('type') !== 'catalog') {
					var catPreds = triggerNode.predecessors('node[type="catalog"]');
					if (catPreds && catPreds.length) {
						cat = catPreds.first();
					}
				}
				if (cat && cat.length && cat.data('type') === 'catalog') {
					catalogsToLayout = cy.collection().union(cat);
				}
			} else {
				// Only reset catalog positions when doing a full layout (no trigger node)
				// This prevents spacing changes during manual expand/collapse
				var catalogSpacing = 600;
				visibleCatalogs.forEach(function(cat, idx) {
					cat.position({ x: 200 + (idx * catalogSpacing), y: 200 });
				});
			}

			// Dagre options for strict top-to-bottom layout
			var dagreOptions = {
				name: 'dagre',
				fit: false,
				animate: false,
				rankDir: 'TB',
				rankdir: 'TB',
				ranker: 'network-simplex',
				nodeDimensionsIncludeLabels: true,
				nodeSep: 160,
				nodesep: 160,
				rankSep: 180,
				ranksep: 180,
				edgeSep: 80,
				edgesep: 80
			};

			function getVisibleTreeNodes(catalogNode) {
				var desc = catalogNode.successors().nodes().not('.collapsed').not('.hidden').not('.hidden-by-filter');
				return cy.collection().union(catalogNode).union(desc);
			}
			function getVisibleTreeEdges(treeNodes) {
				return treeNodes.connectedEdges().filter(function(e) {
					if (e.hasClass('collapsed')) return false;
					if (e.source().hasClass && e.source().hasClass('hidden')) return false;
					if (e.target().hasClass && e.target().hasClass('hidden')) return false;
					if (e.source().hasClass && e.source().hasClass('hidden-by-filter')) return false;
					if (e.target().hasClass && e.target().hasClass('hidden-by-filter')) return false;
					return treeNodes.contains(e.source()) && treeNodes.contains(e.target());
				});
			}
			function translateNodes(nodes, dx, dy) {
				nodes.forEach(function(n) {
					if (!n.data('pinned')) {
						n.position({ x: n.position('x') + dx, y: n.position('y') + dy });
					}
				});
			}

			// 1) Layout only the affected tree(s), anchored so the catalog node stays put.
			catalogsToLayout.forEach(function(catalog) {
				var treeNodes = getVisibleTreeNodes(catalog);
				var treeEdges = getVisibleTreeEdges(treeNodes);
				var treeElements = treeNodes.union(treeEdges);
				if (!treeNodes.length) return;

				var anchorPos = { x: catalog.position('x'), y: catalog.position('y') };
				var layout = treeElements.layout(dagreOptions);
				layout.run();

				// Re-anchor to keep catalog in place (prevents the whole screen “jumping”)
				var afterPos = { x: catalog.position('x'), y: catalog.position('y') };
				translateNodes(treeNodes, anchorPos.x - afterPos.x, anchorPos.y - afterPos.y);

				if (DEBUG_LAYOUT) {
					console.log('Laid out tree for catalog', catalog.id(), 'nodes', treeNodes.length, 'edges', treeEdges.length);
				}
			});

			// 2) Never overlap across trees: pack trees horizontally with MINIMAL movement.
			// Keep current positions as much as possible; only shift right when overlap occurs.
			var treeGap = 250;
			var trees = [];
			visibleCatalogs.forEach(function(catalog) {
				var treeNodes = getVisibleTreeNodes(catalog);
				if (!treeNodes.length) return;
				trees.push({
					catalog: catalog,
					nodes: treeNodes,
					bb: treeNodes.boundingBox()
				});
			});

			trees.sort(function(a, b) { return a.bb.x1 - b.bb.x1; });
			var rightEdge = null;
			trees.forEach(function(t) {
				// Recompute in case a previous tree move changed things
				t.bb = t.nodes.boundingBox();
				if (rightEdge === null) {
					rightEdge = t.bb.x2;
					return;
				}
				var minX1 = rightEdge + treeGap;
				if (t.bb.x1 < minX1) {
					var dx = minX1 - t.bb.x1;
					translateNodes(t.nodes, dx, 0);
					t.bb = t.nodes.boundingBox();
				}
				rightEdge = Math.max(rightEdge, t.bb.x2);
			});

			// Restore the user's viewport (no zoom/pan changes)
			cy.zoom(prevZoom);
			cy.pan(prevPan);
		}

		// Initialize with everything except catalogs collapsed
		function collapseAll() {
	// Check if there are any non-catalog nodes that aren't already collapsed
	var hasExpandedNodes = cy.nodes().not('.hidden').not('[type="catalog"]').not('.collapsed').length > 0;
	
	// Only proceed if there's something to collapse
	if (!hasExpandedNodes) {
		return; // Everything already collapsed, keep positions as-is
	}
		
		// Clear all pinned flags to reset positions to default layout
		cy.nodes().forEach(function(n) {
			n.data('pinned', false);
		});
		
		cy.nodes().not('.hidden').forEach(function(n) {
			if (n.data('type') !== 'catalog') {
				n.addClass('collapsed');
			}
		});
		cy.edges().not('.hidden').addClass('collapsed');
		
		// Reset catalog positions to default layout
		runVisibleLayout();
	}

	function expandAll() {
		// Check if there are any collapsed nodes first
		var hasCollapsedNodes = cy.nodes('.collapsed').not('.hidden').length > 0;
		var hasCollapsedEdges = cy.edges('.collapsed').not('.hidden').length > 0;
		
		// Only proceed if there's something to expand
		if (!hasCollapsedNodes && !hasCollapsedEdges) {
			return; // Nothing to expand, keep positions as-is
		}
		
		// Clear all pinned flags to reset positions to default layout
		cy.nodes().forEach(function(n) {
			n.data('pinned', false);
		});
		
		cy.nodes().not('.hidden').removeClass('collapsed');
		cy.edges().not('.hidden').removeClass('collapsed');
		runVisibleLayout();
	}
	
	function rearrangeAll() {
		// Clear all pinned flags to reset all nodes to default layout positions
		cy.nodes().forEach(function(n) {
			n.data('pinned', false);
		});
		
		// Rearrange all visible nodes without changing collapsed state
		runVisibleLayout();
	}

	function toggleNodeChildren(node) {
			var nodeType = node.data('type');
			var nodeId = node.id();
			var outgoers = node.outgoers();
			var childNodes = outgoers.nodes();
			var visibleChildren = childNodes.filter(function(n) { return !n.hasClass('collapsed'); });
			
			// Don't do anything if node has no children at all
			if (childNodes.length === 0) return;

			// If any children are visible, collapse. If all are collapsed, expand.
			if (visibleChildren.length === 0) {
		// Collect all children that will be expanded (ONLY direct children via non-SoD edges)
		var expandingNodes = cy.collection();
		node.outgoers().edges().forEach(function(e) {
			if (e.source().id() === nodeId && e.data('type') !== 'sod-conflict') {
				e.removeClass('collapsed');
				var child = e.target();
				child.removeClass('collapsed');
				expandingNodes = expandingNodes.union(child);
				
				// If expanding a policy, also expand all sequential approval stages
				if (nodeType === 'policy' && child.data('type') === 'approval-stage') {
					(function expandApprovalChain(approvalNode) {
						approvalNode.outgoers().forEach(function(ele) {
							if (ele.isEdge() && ele.data('type') === 'approval-seq') {
								ele.removeClass('collapsed');
								var nextApproval = ele.target();
								if (nextApproval.data('type') === 'approval-stage') {
									nextApproval.removeClass('collapsed');
									expandingNodes = expandingNodes.union(nextApproval);
									expandApprovalChain(nextApproval);
								}
							}
						});
					})(child);
				}
				
			}
		});
		
		// If expanding a policy, auto-expand ALL sibling policies for this access package
		if (nodeType === 'policy') {
			// Find parent access package
			var parentPackage = node.incomers('node[type="package"]').first();
			if (parentPackage.length) {
				// Find all sibling policies of this package
				var siblingPolicies = parentPackage.outgoers('node[type="policy"]');
				siblingPolicies.forEach(function(siblingPolicy) {
					if (siblingPolicy.id() !== nodeId) {
						// Expand this sibling policy's direct children
						siblingPolicy.outgoers().edges().forEach(function(siblingEdge) {
							if (siblingEdge.data('type') !== 'sod-conflict') {
								siblingEdge.removeClass('collapsed');
								var siblingChild = siblingEdge.target();
								siblingChild.removeClass('collapsed');
								expandingNodes = expandingNodes.union(siblingChild);
								
								// Also expand approval chains for sibling policies
								if (siblingChild.data('type') === 'approval-stage') {
									(function expandApprovalChain(approvalNode) {
										approvalNode.outgoers().forEach(function(ele) {
											if (ele.isEdge() && ele.data('type') === 'approval-seq') {
												ele.removeClass('collapsed');
												var nextApproval = ele.target();
												if (nextApproval.data('type') === 'approval-stage') {
													nextApproval.removeClass('collapsed');
													expandingNodes = expandingNodes.union(nextApproval);
													expandApprovalChain(nextApproval);
												}
											}
										});
									})(siblingChild);
								}
							}
						});
					}
				});
			}
		}
		
		// Position newly expanded children to prevent overlaps
		if (expandingNodes.length > 0) {
			var parentPos = node.position();
			var parentType = node.data('type');
			var childrenArray = expandingNodes.toArray();
			
			// Get all currently visible nodes to check for overlaps
			var visibleNodes = cy.nodes().filter(function(n) {
				return !n.hasClass('collapsed') && !n.hasClass('hidden');
			});
			
			// Helper to check if position overlaps with existing nodes
			function hasOverlap(x, y, nodeWidth, nodeHeight, excludeIds) {
				var buffer = 50;
				for (var i = 0; i < visibleNodes.length; i++) {
					var vn = visibleNodes[i];
					if (excludeIds.indexOf(vn.id()) !== -1) continue;
					var vnPos = vn.position();
					var vnWidth = vn.width() || 150;
					var vnHeight = vn.height() || 50;
					if (Math.abs(x - vnPos.x) < (nodeWidth + vnWidth) / 2 + buffer &&
						Math.abs(y - vnPos.y) < (nodeHeight + vnHeight) / 2 + buffer) {
						return true;
					}
				}
				return false;
			}
			
			var nodeWidth = 150;
			var nodeHeight = 50;
			var positioningIds = childrenArray.map(function(c) { return c.id(); });
			
			var baseY = parentPos.y + 180; // Match Dagre rankSep
			var horizontalSpacing = 160; // Match Dagre nodeSep
			var verticalSpacing = 180; // Match Dagre rankSep
			
			// Check if we have approval stages connected by approval-seq edges
			var approvalStageChain = [];
			var otherChildren = [];
			
			childrenArray.forEach(function(child) {
				if (child.data('type') === 'approval-stage') {
					approvalStageChain.push(child);
				} else {
					otherChildren.push(child);
				}
			});
			
			// If we have approval stages, find the first one and position the chain vertically
			if (approvalStageChain.length > 0) {
				// Find the first approval stage (one with no incoming approval-seq edge from another stage in chain)
				var firstStage = approvalStageChain[0];
				for (var i = 0; i < approvalStageChain.length; i++) {
					var hasIncomingFromChain = false;
					approvalStageChain[i].incomers().edges().forEach(function(e) {
						if (e.data('type') === 'approval-seq') {
							hasIncomingFromChain = true;
						}
					});
					if (!hasIncomingFromChain) {
						firstStage = approvalStageChain[i];
						break;
					}
				}
				
				// Position the first stage
				var stageX = parentPos.x;
				if (otherChildren.length > 0) {
					// If there are other children, offset approval stage to the left
					stageX = parentPos.x - (horizontalSpacing / 2);
				}
				
				var currentY = baseY;
				var currentStage = firstStage;
				var positionedStages = [];
				
				// Walk the chain and position each stage vertically
				while (currentStage) {
					var attempts = 0;
					while (hasOverlap(stageX, currentY, nodeWidth, nodeHeight, positioningIds) && attempts < 20) {
						currentY += 100;
						attempts++;
					}
					
					currentStage.position({ x: stageX, y: currentY });
					positionedStages.push(currentStage.id());
					
					// Find next stage in chain
					var nextStage = null;
					currentStage.outgoers().edges().forEach(function(e) {
						if (e.data('type') === 'approval-seq') {
							var target = e.target();
							if (target.data('type') === 'approval-stage' && positionedStages.indexOf(target.id()) === -1) {
								nextStage = target;
							}
						}
					});
					
					currentStage = nextStage;
					currentY += verticalSpacing;
				}
			}
			
			// Position other (non-approval) children
			if (otherChildren.length > 0) {
				// If there's only 1 other child, position it straight down
				if (otherChildren.length === 1) {
					var child = otherChildren[0];
					var targetX = parentPos.x;
					if (approvalStageChain.length > 0) {
						// If approval stages exist, offset to the right
						targetX = parentPos.x + (horizontalSpacing / 2);
					}
					var targetY = baseY;
					
					// Check for overlaps and move down if needed
					var attempts = 0;
					while (hasOverlap(targetX, targetY, nodeWidth, nodeHeight, positioningIds) && attempts < 20) {
						targetY += 100;
						attempts++;
					}
					
					child.position({ x: targetX, y: targetY });
				}
				// Multiple other children: arrange horizontally on same level
				else if (otherChildren.length > 1) {
					// Find a Y level that doesn't overlap
					var rowY = baseY;
					var attempts = 0;
					var maxAttempts = 20;
					
					// Calculate positions for all other children on same row
					var totalWidth = (otherChildren.length - 1) * horizontalSpacing;
					var startX = parentPos.x - (totalWidth / 2);
					if (approvalStageChain.length > 0) {
						// If approval stages exist, offset to the right
						startX = parentPos.x + (horizontalSpacing / 2) - (totalWidth / 2);
					}
					
					// Keep checking rows until we find one with no overlaps
					while (attempts < maxAttempts) {
						var hasAnyOverlap = false;
						
						for (var i = 0; i < otherChildren.length; i++) {
							var x = startX + (i * horizontalSpacing);
							if (hasOverlap(x, rowY, nodeWidth, nodeHeight, positioningIds)) {
								hasAnyOverlap = true;
								break;
							}
						}
						
						if (!hasAnyOverlap) break;
						rowY += 100; // Move down and try next row
						attempts++;
					}
					
					// Position all other children on the found row
					otherChildren.forEach(function(child, idx) {
						child.position({
							x: startX + (idx * horizontalSpacing),
							y: rowY
						});
					});
				}
			}
		}
	} else {
		// Collapse all descendants
		function collapseDescendants(n) {
			n.outgoers().forEach(function(ele) {
				if (ele.isEdge()) {
					ele.addClass('collapsed');
				} else if (ele.isNode()) {
					ele.addClass('collapsed');
					collapseDescendants(ele);
				}
			});
		}
		collapseDescendants(node);
		
		// Don't reposition anything on collapse - just hide the nodes
		// Full layout is only done by the buttons (Expand All, Collapse All, Rearrange)
		
		// After collapsing policy nodes, create synthetic fallback edges only for resource-group nodes
		// Resources should NEVER be linked directly to packages, only to resource-group nodes
		// Only create fallbacks when collapsing nodes below the package level (policy, resource-group, etc.)
		if (node.data('type') !== 'package' && node.data('type') !== 'catalog') {
			(function createFallbacks(n) {
				var resourceGroups = n.outgoers('node[type="resource-group"]');
				resourceGroups.forEach(function(rg) {
					var visiblePolicyParents = rg.incomers('node[type="policy"]').filter(function(p) { return !p.hasClass('collapsed') && !p.hasClass('hidden'); });
					if (visiblePolicyParents.length === 0) {
						// Find nearest package (NOT catalog) to attach fallback edge
						var pkg = n.predecessors('node[type="package"]').first();
						if (pkg && pkg.length) {
							var fallbackId = 'edge-fallback-' + pkg.id() + '-' + rg.id();
							if (cy.getElementById(fallbackId).length === 0) {
								cy.add({ data: { id: fallbackId, source: pkg.id(), target: rg.id(), type: 'resource-fallback', synthetic: true } });
							}
						}
					}
				});
			})(node);
		}

	}
	
	// Update SoD edge visibility - show SoD edges only when both connected packages are visible
	cy.edges('[type="sod-conflict"]').forEach(function(sodEdge) {
		var source = sodEdge.source();
		var target = sodEdge.target();
		
		// Show SoD edge if both packages are visible (not collapsed)
		if (source.length && target.length && 
		    !source.hasClass('collapsed') && !target.hasClass('collapsed')) {
			sodEdge.removeClass('collapsed');
		} else {
			sodEdge.addClass('collapsed');
		}
	});
}

// Initialize collapsed state
	// First, run initial layout for catalogs to position them properly
	var initialCatalogs = cy.nodes('[type="catalog"]').not('.hidden');
	if (initialCatalogs.length > 0) {
		// Position catalogs in a horizontal row
		var catalogSpacing = 600;
		initialCatalogs.forEach(function(cat, idx) {
			cat.position({ x: 200 + (idx * catalogSpacing), y: 200 });
		});
	}
	collapseAll();

// Mark nodes that have SoD conflicts with a visual indicator
function updateSoDIndicators() {
	// Remove existing indicators
	cy.nodes().removeClass('has-sod-conflict');
	
	// Find all SoD conflict edges
	cy.edges('[type="sod-conflict"]').forEach(function(sodEdge) {
		var source = sodEdge.source();
		var target = sodEdge.target();
		
		// Mark both nodes involved in the conflict
		if (source.length) source.addClass('has-sod-conflict');
		if (target.length) target.addClass('has-sod-conflict');
	});
}
updateSoDIndicators();

// Initialize drag tracking variable
var dragStartPositions = {};

cy.on('dragstart', 'node', function(evt) {
		var n = evt.target;
		dragStartPositions = {};
		dragStartPositions[n.id()] = { x: n.position('x'), y: n.position('y') };
		// Store initial positions of all descendants
		n.successors('node').forEach(function(child) {
			dragStartPositions[child.id()] = { x: child.position('x'), y: child.position('y') };
		});
	});
	
	cy.on('drag', 'node', function(evt) {
		if (!dragStartPositions) return;
		var n = evt.target;
		if (!dragStartPositions[n.id()]) return;
		
		var dx = n.position('x') - dragStartPositions[n.id()].x;
		var dy = n.position('y') - dragStartPositions[n.id()].y;
		
		// Move all descendants by the same delta
		n.successors('node').forEach(function(child) {
			if (dragStartPositions[child.id()] && !child.grabbed()) {
				child.position({
					x: dragStartPositions[child.id()].x + dx,
					y: dragStartPositions[child.id()].y + dy
				});
			}
		});
	});

	// Mark nodes as pinned when drag ends (but don't lock - allow endless moving)
	cy.on('dragfreeon', 'node', function(evt) {
		var n = evt.target;
		n.data('pinned', true);
		// Also pin all descendants and clear their saved positions
		n.successors('node').forEach(function(child) {
			child.data('pinned', true);
			child.scratch('savedPosition', null);
		});
		dragStartPositions = null;
	});

		// Multi-layer filter dropdown logic
		var filterDropdownToggle = document.getElementById('filter-dropdown-toggle');
		var filterMainMenu = document.getElementById('filter-main-menu');
		var catalogOptions = document.getElementById('catalog-options');
		var packageOptions = document.getElementById('package-options');
		var resourceOptions = document.getElementById('resource-options');
		var extensionOptions = document.getElementById('extension-options');
		var catalogSelectAll = document.getElementById('catalog-select-all');
		var packageSelectAll = document.getElementById('package-select-all');
		var resourceSelectAll = document.getElementById('resource-select-all');
		var extensionSelectAll = document.getElementById('extension-select-all');

		// Filter state
		var filterState = {
			catalogs: [],
			packages: [],
			resourceTypes: [],
			extensions: []
		};

		function updateStats() {
			document.getElementById('stat-catalogs').textContent = cy.nodes('[type="catalog"]').not('.hidden').length || 0;
			document.getElementById('stat-packages').textContent = cy.nodes('[type="package"]').not('.hidden').length || 0;
			document.getElementById('stat-policies').textContent = cy.nodes('[type="policy"]').not('.hidden').length || 0;
			document.getElementById('stat-resources').textContent = cy.nodes('[type="resource"]').not('.hidden').not('.hidden-by-filter').length || 0;
			document.getElementById('stat-extensions').textContent = cy.nodes('[type="custom-extension"]').not('.hidden').not('.hidden-by-filter').length || 0;
		}

		function applyCatalogFilter(selected) {
			cy.nodes('[type="catalog"]').forEach(function(cat) {
				if (selected.indexOf(cat.id()) === -1) {
					cat.addClass('hidden');
					cat.successors().forEach(function(n) { n.addClass('hidden'); });
					cat.connectedEdges().forEach(function(e) { e.addClass('hidden'); });
				} else {
					cat.removeClass('hidden');
					// Don't automatically unhide successors - let package filter handle it
					cat.outgoers('edge').forEach(function(e) { 
						if (!e.target().hasClass('hidden')) {
							e.removeClass('hidden');
						}
					});
				}
			});
		}

		function applyPackageFilter(selected) {
			cy.nodes('[type="package"]').forEach(function(pkg) {
				var catalogHidden = pkg.predecessors('[type="catalog"]').hasClass('hidden');
				
				if (selected.indexOf(pkg.id()) === -1) {
					pkg.addClass('hidden');
					pkg.successors().forEach(function(n) { n.addClass('hidden'); });
					pkg.connectedEdges().forEach(function(e) { e.addClass('hidden'); });
				} else {
					if (!catalogHidden) {
						pkg.removeClass('hidden');
						// Unhide successors
						pkg.successors().forEach(function(n) { n.removeClass('hidden'); });
						pkg.connectedEdges().forEach(function(e) { e.removeClass('hidden'); });
					}
				}
			});
		}

		function applyResourceTypeFilter(selectedTypes) {
			cy.nodes('[type="resource"],[type="orphaned-resource"]').forEach(function(res) {
				var payload = res.data('payload') || {};
				var typeLabel = payload.typeLabel || '';
				if (selectedTypes.indexOf(typeLabel) === -1) {
					res.addClass('hidden-by-filter');
				} else {
					res.removeClass('hidden-by-filter');
				}
			});
		}

		function applyCustomExtensionFilter(selected) {
			// selected contains comma-separated node IDs for each unique extension
			var selectedNodeIds = {};
			selected.forEach(function(nodeIdList) {
				var ids = nodeIdList.split(',');
				ids.forEach(function(id) { selectedNodeIds[id] = true; });
			});
			
			cy.nodes('[type="custom-extension"]').forEach(function(ext) {
				if (!selectedNodeIds[ext.id()]) {
					ext.addClass('hidden-by-filter');
				} else {
					ext.removeClass('hidden-by-filter');
				}
			});
		}

		function applyAllFilters() {
			applyCatalogFilter(filterState.catalogs);
			applyPackageFilter(filterState.packages);
			applyResourceTypeFilter(filterState.resourceTypes);
			applyCustomExtensionFilter(filterState.extensions);
			updateStats();
			runVisibleLayout();
		}

		// Cascading filter helpers: upstream changes repopulate downstream dropdowns
		function cascadeFromCatalogs() {
			populatePackageSelect(filterState.catalogs);
			cascadeFromPackages();
		}
		function cascadeFromPackages() {
			populateResourceTypeSelect(filterState.packages);
			populateCustomExtensionSelect(filterState.packages);
			applyAllFilters();
		}

		function populateCatalogSelect() {
			if (!catalogOptions) return;
			catalogOptions.innerHTML = '';
			filterState.catalogs = [];
			cy.nodes('[type="catalog"]').forEach(function(c) {
				var id = c.id();
				var label = c.data('label') || c.id();
				filterState.catalogs.push(id);
				var wrapper = document.createElement('div');
				wrapper.style.marginBottom = '6px';
				wrapper.innerHTML = '<label style="display:flex; align-items:flex-start; max-width:280px; word-wrap:break-word; cursor:pointer;"><input type="checkbox" class="catalog-option" value="' + id + '" checked style="margin-top:2px; margin-right:6px; flex-shrink:0;" /><span style="flex:1; word-break:break-word;">' + htmlEscape(label) + '</span></label>';
				catalogOptions.appendChild(wrapper);
			});
			var opts = catalogOptions.querySelectorAll('input.catalog-option');
			opts.forEach(function(i) { 
				i.addEventListener('change', function() {
					filterState.catalogs = Array.from(opts).filter(function(o){ return o.checked; }).map(function(o){ return o.value; });
					catalogSelectAll.checked = (filterState.catalogs.length === opts.length);
					cascadeFromCatalogs();
				});
			});
			if (catalogSelectAll) {
				catalogSelectAll.checked = true;
				catalogSelectAll.addEventListener('change', function() {
					var ch = catalogSelectAll.checked;
					opts.forEach(function(i){ i.checked = ch; });
					filterState.catalogs = ch ? Array.from(opts).map(function(o){ return o.value; }) : [];
					cascadeFromCatalogs();
				});
			}
		}

		function populatePackageSelect(scopeCatalogIds) {
			if (!packageOptions) return;
			packageOptions.innerHTML = '';
			filterState.packages = [];
			var packages = cy.nodes('[type="package"]');
			if (scopeCatalogIds && scopeCatalogIds.length > 0) {
				packages = packages.filter(function(p) {
					var parentCats = p.predecessors('[type="catalog"]');
					var inScope = false;
					parentCats.forEach(function(c) {
						if (scopeCatalogIds.indexOf(c.id()) !== -1) inScope = true;
					});
					return inScope;
				});
			}
			packages.forEach(function(p) {
				var id = p.id();
				var label = p.data('label') || p.id();
				filterState.packages.push(id);
				var wrapper = document.createElement('div');
				wrapper.style.marginBottom = '6px';
				wrapper.innerHTML = '<label style="display:flex; align-items:flex-start; max-width:280px; word-wrap:break-word; cursor:pointer;"><input type="checkbox" class="package-option" value="' + id + '" checked style="margin-top:2px; margin-right:6px; flex-shrink:0;" /><span style="flex:1; word-break:break-word;">' + htmlEscape(label) + '</span></label>';
				packageOptions.appendChild(wrapper);
			});
			var opts = packageOptions.querySelectorAll('input.package-option');
			opts.forEach(function(i) { 
				i.addEventListener('change', function() {
					filterState.packages = Array.from(opts).filter(function(o){ return o.checked; }).map(function(o){ return o.value; });
					packageSelectAll.checked = (filterState.packages.length === opts.length);
					cascadeFromPackages();
				});
			});
			if (packageSelectAll) {
				packageSelectAll.checked = true;
				packageSelectAll.addEventListener('change', function() {
					var ch = packageSelectAll.checked;
					opts.forEach(function(i){ i.checked = ch; });
					filterState.packages = ch ? Array.from(opts).map(function(o){ return o.value; }) : [];
					cascadeFromPackages();
				});
			}
		}

		function populateResourceTypeSelect(scopePackageIds) {
			if (!resourceOptions) return;
			resourceOptions.innerHTML = '';
			filterState.resourceTypes = [];
			var typeMap = {};
			var resources = cy.nodes('[type="resource"],[type="orphaned-resource"]');
			if (scopePackageIds && scopePackageIds.length > 0) {
				var scopedResources = cy.collection();
				scopePackageIds.forEach(function(pkgId) {
					var pkg = cy.getElementById(pkgId);
					if (pkg.length) scopedResources = scopedResources.union(pkg.successors('[type="resource"],[type="orphaned-resource"]'));
				});
				resources = scopedResources;
			}
			resources.forEach(function(r) {
				var payload = r.data('payload') || {};
				var typeLabel = payload.typeLabel || 'Unknown';
				if (!typeMap[typeLabel]) typeMap[typeLabel] = true;
			});
			var types = Object.keys(typeMap).sort();
			types.forEach(function(typeLabel) {
				filterState.resourceTypes.push(typeLabel);
				var wrapper = document.createElement('div');
				wrapper.style.marginBottom = '6px';
				wrapper.innerHTML = '<label style="display:flex; align-items:flex-start; max-width:280px; word-wrap:break-word; cursor:pointer;"><input type="checkbox" class="resource-type-option" value="' + htmlEscape(typeLabel) + '" checked style="margin-top:2px; margin-right:6px; flex-shrink:0;" /><span style="flex:1; word-break:break-word;">' + htmlEscape(typeLabel) + '</span></label>';
				resourceOptions.appendChild(wrapper);
			});
			var opts = resourceOptions.querySelectorAll('input.resource-type-option');
			opts.forEach(function(i) { 
				i.addEventListener('change', function() {
					filterState.resourceTypes = Array.from(opts).filter(function(o){ return o.checked; }).map(function(o){ return o.value; });
					resourceSelectAll.checked = (filterState.resourceTypes.length === opts.length);
					applyAllFilters();
				});
			});
			if (resourceSelectAll) {
				resourceSelectAll.checked = true;
				resourceSelectAll.addEventListener('change', function() {
					var ch = resourceSelectAll.checked;
					opts.forEach(function(i){ i.checked = ch; });
					filterState.resourceTypes = ch ? Array.from(opts).map(function(o){ return o.value; }) : [];
					applyAllFilters();
				});
			}
		}

		function populateCustomExtensionSelect(scopePackageIds) {
			if (!extensionOptions) return;
			extensionOptions.innerHTML = '';
			filterState.extensions = [];
			// Deduplicate extensions by their actual extension ID from payload
			var extensionMap = {};
			var extNodes = cy.nodes('[type="custom-extension"]');
			if (scopePackageIds && scopePackageIds.length > 0) {
				var scopedExts = cy.collection();
				scopePackageIds.forEach(function(pkgId) {
					var pkg = cy.getElementById(pkgId);
					if (pkg.length) scopedExts = scopedExts.union(pkg.successors('[type="custom-extension"]'));
				});
				extNodes = scopedExts;
			}
			extNodes.forEach(function(e) {
				var payload = e.data('payload') || {};
				var extensionId = payload.customExtensionId || e.id();
				var label = e.data('label') || e.id();
				var nodeId = e.id();
				
				if (!extensionMap[extensionId]) {
					extensionMap[extensionId] = {
						label: label,
						nodeIds: []
					};
				}
				extensionMap[extensionId].nodeIds.push(nodeId);
			});
			
			// Create filter options for unique extensions
			Object.keys(extensionMap).sort().forEach(function(extensionId) {
				var ext = extensionMap[extensionId];
				var nodeIds = ext.nodeIds.join(',');
				filterState.extensions.push(nodeIds);
				var wrapper = document.createElement('div');
				wrapper.style.marginBottom = '6px';
				wrapper.innerHTML = '<label style="display:flex; align-items:flex-start; max-width:280px; word-wrap:break-word; cursor:pointer;"><input type="checkbox" class="extension-option" value="' + nodeIds + '" checked style="margin-top:2px; margin-right:6px; flex-shrink:0;" /><span style="flex:1; word-break:break-word;">' + htmlEscape(ext.label) + '</span></label>';
				extensionOptions.appendChild(wrapper);
			});
			var opts = extensionOptions.querySelectorAll('input.extension-option');
			opts.forEach(function(i) { 
				i.addEventListener('change', function() {
					filterState.extensions = Array.from(opts).filter(function(o){ return o.checked; }).map(function(o){ return o.value; });
					extensionSelectAll.checked = (filterState.extensions.length === opts.length);
					applyAllFilters();
				});
			});
			if (extensionSelectAll) {
				extensionSelectAll.checked = true;
				extensionSelectAll.addEventListener('change', function() {
					var ch = extensionSelectAll.checked;
					opts.forEach(function(i){ i.checked = ch; });
					filterState.extensions = ch ? Array.from(opts).map(function(o){ return o.value; }) : [];
					applyAllFilters();
				});
			}
		}

		// Populate all filter dropdowns (cascading: catalog -> packages -> resources/extensions)
		populateCatalogSelect();
		populatePackageSelect(filterState.catalogs);
		populateResourceTypeSelect(filterState.packages);
		populateCustomExtensionSelect(filterState.packages);
		updateStats();

		// Filter dropdown toggle
		if (filterDropdownToggle) {
			filterDropdownToggle.addEventListener('click', function(e) {
				e.stopPropagation();
				var open = filterMainMenu.style.display !== 'block';
				if (open) {
					var rect = filterDropdownToggle.getBoundingClientRect();
					filterMainMenu.style.display = 'block';
					filterMainMenu.style.position = 'fixed';
					var top = rect.bottom + 6;
					var left = rect.left;
					filterMainMenu.style.top = top + 'px';
					filterMainMenu.style.left = left + 'px';
				} else {
					filterMainMenu.style.display = 'none';
				}
				filterDropdownToggle.setAttribute('aria-expanded', String(open));
			});
		}

		// Position submenus on hover
		document.querySelectorAll('.filter-category').forEach(function(category) {
			category.addEventListener('mouseenter', function() {
				var submenu = category.querySelector('.filter-submenu');
				if (submenu) {
					var catRect = category.getBoundingClientRect();
					submenu.style.display = 'block';
					submenu.style.position = 'fixed';
					submenu.style.top = catRect.top + 'px';
					submenu.style.left = (catRect.right + 4) + 'px';
				}
			});
			category.addEventListener('mouseleave', function() {
				var submenu = category.querySelector('.filter-submenu');
				if (submenu) {
					submenu.style.display = 'none';
				}
			});
		});

		// Close filter dropdown when clicking outside
		document.addEventListener('click', function(e) {
			if (filterMainMenu && filterMainMenu.style.display === 'block') {
				if (!filterMainMenu.contains(e.target) && e.target !== filterDropdownToggle) {
					filterMainMenu.style.display = 'none';
					if (filterDropdownToggle) filterDropdownToggle.setAttribute('aria-expanded', 'false');
				}
			}
		});

		
		// Set initial viewport: fit visible catalogs then enforce a minimum zoom so labels remain readable
		try {
			var visibleCatalogsInit = cy.nodes('[type="catalog"]').not('.collapsed').not('.hidden');
			if (visibleCatalogsInit.length) {
				cy.fit(visibleCatalogsInit, 80);
				// Prevent excessive zoom-out: ensure at least DEFAULT_ZOOM
				if (cy.zoom() < DEFAULT_ZOOM) {
					var center = cy.center();
					cy.zoom(DEFAULT_ZOOM);
					cy.center(center);
				}
			} else {
				cy.fit();
			}
		} catch (e) {
			cy.fit();
		}

		// Track shift key state
		var shiftPressed = false;
		document.addEventListener('keydown', function(e) {
			if (e.key === 'Shift') shiftPressed = true;
		});
		document.addEventListener('keyup', function(e) {
			if (e.key === 'Shift') {
				shiftPressed = false;
				cy.elements().removeClass('dimmed highlighted');
				cy.elements().style('opacity', 1);
			}
		});

		// Function to highlight connected nodes
		function highlightConnected(node) {
			cy.elements().removeClass('dimmed highlighted');
			cy.elements().style('opacity', 1);
			var nodesToHighlight = cy.collection();
			nodesToHighlight = nodesToHighlight.union(node);

			// For resource nodes, highlight any owning policies and their access packages
			// (resources can be shared by multiple policies within a package)
			if (node.data('type') === 'resource') {
				var policyParents = node.incomers('node[type="policy"]');
				if (policyParents.length > 0) {
					var packageGrandparents = policyParents.incomers('node[type="package"]');
					nodesToHighlight = nodesToHighlight.union(packageGrandparents);
					nodesToHighlight = nodesToHighlight.union(policyParents);
					nodesToHighlight = nodesToHighlight.union(node.edgesWith(policyParents));
					nodesToHighlight = nodesToHighlight.union(policyParents.edgesWith(packageGrandparents));
				}
			} else {
				// Normal highlighting for other nodes
				var connected = node.neighborhood();
				nodesToHighlight = nodesToHighlight.union(connected);
			}

			nodesToHighlight.addClass('highlighted');
			cy.elements().not(nodesToHighlight).addClass('dimmed').style('opacity', 0.2);
			nodesToHighlight.style('opacity', 1);
		}

		// Shift + click highlighting
		cy.on('click', 'node', function(evt) {
			if (shiftPressed) {
				highlightConnected(evt.target);
				evt.stopPropagation();
			}
		});

		// Shift + mouseover highlighting
		cy.on('mouseover', 'node', function(evt) {
			if (shiftPressed) {
				highlightConnected(evt.target);
			}
		});

		// Double-click to expand/collapse
		cy.on('dblclick', 'node', function(evt) {
			var node = evt.target;
			toggleNodeChildren(node);
			evt.stopPropagation();
		});

		cy.on('tap', 'node', function(evt) {
			var n = evt.target;
			var payloadHtml = renderDetails({ type: n.data('type'), payload: n.data('payload') || {} });
			showDetails(n.data('label') || n.id(), payloadHtml);
		});

		var searchEl = document.getElementById('search');
		var searchResultsEl = document.getElementById('search-results');
		var searchResultsListEl = document.getElementById('search-results-list');
	var searchResultsHeaderEl = document.getElementById('search-results-header');
	var searchResultsToggleEl = document.getElementById('search-results-toggle');
	var resultCountEl = document.getElementById('result-count');
	var searchResultsExpanded = true;
	
	// Toggle search results list
	searchResultsHeaderEl.addEventListener('click', function() {
		searchResultsExpanded = !searchResultsExpanded;
		if (searchResultsExpanded) {
			searchResultsListEl.style.display = 'block';
			searchResultsToggleEl.textContent = '▼';
		} else {
			searchResultsListEl.style.display = 'none';
			searchResultsToggleEl.textContent = '▶';
		}
	});
	
	function jumpToNode(nodeId) {
		var node = cy.getElementById(nodeId);
		if (node.length) {
				// Expand all ancestors to show full hierarchy
				var ancestors = [];
				var current = node;
				
				// Walk up the tree to find all collapsed ancestors
				while (current.length) {
					if (current.hasClass('collapsed')) {
						ancestors.unshift(current); // Add to front so we expand from root down
					}
					// Move to parent
					var parents = current.incomers('node').filter(function(n) {
						return !n.hasClass('hidden');
					});
					if (parents.length) {
						current = parents.first();
					} else {
						break;
					}
				}
				
				// Expand each collapsed ancestor in order (root to leaf)
				ancestors.forEach(function(ancestor) {
					var parent = ancestor.incomers('node').filter(function(n) {
						return !n.hasClass('hidden');
					}).first();
					if (parent.length) {
						toggleNodeChildren(parent);
					}
				});
				
				// Center and zoom to node
				cy.animate({
					center: { eles: node },
					zoom: 1.5
				}, {
					duration: 500
				});
				// Show details
				var payloadHtml = renderDetails({ type: node.data('type'), payload: node.data('payload') || {} });
				showDetails(node.data('label') || node.id(), payloadHtml);
			}
		}
		
		searchEl.addEventListener('input', function(e) {
			var term = (e.target.value || '').toLowerCase();
			if (!term) {
				// Clear highlighting when search is empty
				cy.elements().removeClass('dimmed highlighted');
				cy.elements().style('opacity', 1);
				searchResultsEl.style.display = 'none';
			} else {
				var matches = [];
				// Highlight matching nodes and dim others
				cy.nodes().forEach(function(n) {
					var lbl = (n.data('label') || '').toLowerCase();
					if (lbl.indexOf(term) !== -1) {
						n.removeClass('dimmed').addClass('highlighted');
						n.style('opacity', 1);
						matches.push(n);
					} else {
						n.removeClass('highlighted').addClass('dimmed');
						n.style('opacity', 0.2);
					}
				});
				// Also dim edges
				cy.edges().removeClass('highlighted').addClass('dimmed').style('opacity', 0.2);
				
				// Populate search results panel
				resultCountEl.textContent = matches.length;
				searchResultsListEl.innerHTML = '';
				if (matches.length > 0) {
					matches.forEach(function(n) {
						var item = document.createElement('div');
						item.className = 'search-result-item';
						
						// Get catalog and package names for this node
						var catalogName = getCatalogName(n);
						var packageName = getPackageName(n);
						
						// Build HTML with catalog and package on separate lines if available
						var html = '';
						if (catalogName) {
							html += '<div class="search-result-catalog">Catalog: ' + catalogName + '</div>';
						}
						if (packageName) {
							html += '<div class="search-result-package">Access Package: ' + packageName + '</div>';
						}
						html += '<div>' + n.data('label') + '<span class="search-result-type">(' + n.data('type') + ')</span></div>';
						
						item.innerHTML = html;
						item.onclick = function() { jumpToNode(n.id()); };
						searchResultsListEl.appendChild(item);
					});
					searchResultsEl.style.display = 'block';
				} else {
					searchResultsEl.style.display = 'none';
				}
			}
		});

		document.getElementById('fit').addEventListener('click', function() { cy.fit(); });
		document.getElementById('zoom-in').addEventListener('click', function() { cy.zoom(cy.zoom() * 1.1); cy.center(); });
		document.getElementById('zoom-out').addEventListener('click', function() { cy.zoom(cy.zoom() * 0.9); cy.center(); });
		document.getElementById('collapse-all').addEventListener('click', function() { collapseAll(); });
		document.getElementById('expand-all').addEventListener('click', function() { expandAll(); });
		document.getElementById('rearrange').addEventListener('click', function() { rearrangeAll(); });
		var sodButton = document.getElementById('toggle-sod');
		var sodVisible = false;
		sodButton.addEventListener('click', function() {
			cy.$('edge[type="sod-conflict"]').toggleClass('sod-hidden');
			sodVisible = !sodVisible;
			sodButton.textContent = sodVisible ? 'Hide SoD ✓' : 'Show SoD';
			sodButton.style.backgroundColor = sodVisible ? '#dc3545' : '';
			sodButton.style.color = sodVisible ? 'white' : '';
		});
		// Initially hide SoD edges
		cy.$('edge[type="sod-conflict"]').addClass('sod-hidden');
		sodButton.textContent = 'Show SoD';
		
		// Export dropdown toggle
		var exportDropdownToggle = document.getElementById('export-dropdown-toggle');
		var exportMenu = document.getElementById('export-menu');
		if (exportDropdownToggle) {
			exportDropdownToggle.addEventListener('click', function(e) {
				e.stopPropagation();
				var open = exportMenu.style.display !== 'block';
				if (open) {
					var rect = exportDropdownToggle.getBoundingClientRect();
					exportMenu.style.display = 'block';
					exportMenu.style.position = 'fixed';
					exportMenu.style.top = (rect.bottom + 6) + 'px';
					exportMenu.style.left = rect.left + 'px';
				} else {
					exportMenu.style.display = 'none';
				}
			});
		}
		
		// Close export dropdown when clicking outside
		document.addEventListener('click', function(e) {
			if (exportMenu && exportMenu.style.display === 'block') {
				if (!exportMenu.contains(e.target) && e.target !== exportDropdownToggle) {
					exportMenu.style.display = 'none';
				}
			}
		});
		
		// Helper to get timestamp for filenames
		function getTimestamp() {
			var now = new Date();
			return now.getFullYear() + 
				String(now.getMonth() + 1).padStart(2, '0') +
				String(now.getDate()).padStart(2, '0') + '-' +
				String(now.getHours()).padStart(2, '0') +
				String(now.getMinutes()).padStart(2, '0') +
				String(now.getSeconds()).padStart(2, '0');
		}
		
		// Export handlers
		document.querySelectorAll('.export-item').forEach(function(item) {
			item.addEventListener('click', function() {
				var format = item.getAttribute('data-format');
				exportMenu.style.display = 'none';
				
				if (format === 'png') {
					var png = cy.png({
						bg: document.body.getAttribute('data-theme') === 'dark' ? '#0f172a' : '#ffffff',
						full: true,
						scale: 2
					});
					var a = document.createElement('a');
					a.href = png;
					a.download = 'access-packages-' + getTimestamp() + '.png';
					a.click();
				}
				else if (format === 'jpeg') {
					var jpg = cy.jpg({
						bg: document.body.getAttribute('data-theme') === 'dark' ? '#0f172a' : '#ffffff',
						full: true,
						scale: 2,
						quality: 0.95
					});
					var a = document.createElement('a');
					a.href = jpg;
					a.download = 'access-packages-' + getTimestamp() + '.jpeg';
					a.click();
				}
				else if (format === 'json') {
					exportJSON();
				}
				else if (format === 'markdown') {
					exportMarkdown();
				}
			});
		});
		
		function exportJSON() {
			// Helper to translate #EXT# guest emails back to original format
			function translateGuestEmailForExport(upn) {
				if (!upn || typeof upn !== 'string') return upn;
				// Match pattern: username_domain#EXT#@tenant.onmicrosoft.com
				var extMatch = upn.match(/^(.+)_(.+)#EXT#@.+$/);
				if (extMatch) {
					// Reconstruct as username@domain
					return extMatch[1] + '@' + extMatch[2].replace(/_/g, '.');
				}
				return upn;
			}
			
			// Helper to translate approver objects to readable format
			function translateApprover(approver) {
				if (!approver || typeof approver !== 'object') return null;
				var type = approver['@odata.type'] || '';
				
				if (type === '#microsoft.graph.singleUser') {
					return {
						type: 'Single User',
						displayName: approver.displayName || null,
						userPrincipalName: translateGuestEmailForExport(approver.userPrincipalName) || null,
						id: approver.id || null
					};
				} else if (type === '#microsoft.graph.groupMembers') {
					return {
						type: 'Group Members',
						groupId: approver.groupId || null,
						description: approver.description || null
					};
				} else if (type === '#microsoft.graph.requestorManager') {
					return {
						type: 'Requestor Manager',
						managerLevel: approver.managerLevel || 1
					};
				} else if (type === '#microsoft.graph.internalSponsors') {
					return { type: 'Internal Sponsors' };
				} else if (type === '#microsoft.graph.externalSponsors') {
					return { type: 'External Sponsors' };
				} else if (type === '#microsoft.graph.targetUserSponsors') {
					return { type: 'Sponsor' };
				} else if (type === '#microsoft.graph.attributeRuleMembers') {
					return {
						type: 'Attribute Rule Members',
						membershipRule: approver.membershipRule || approver.filter || null
					};
				}
				return approver;
			}
			
			function translateApprovers(approvers) {
				if (!Array.isArray(approvers)) return [];
				return approvers.map(translateApprover).filter(function(a) { return a !== null; });
			}
			
			// Use RAW embedded data instead of traversing Cytoscape to ensure complete data
			var rawNodes = data.nodes || [];
			var rawEdges = data.edges || [];
			var visibleCatalogIds = cy.nodes('[type="catalog"]').not('.hidden').map(function(n) { return n.id(); });
			
			// Build parent map from edges (nodes don't have parent property, only edges define relationships)
			var parentMap = {};
			rawEdges.forEach(function(edge) {
				if (edge.source && edge.target) {
					parentMap[edge.target] = edge.source;
				}
			});
			
			// Helper to get child nodes by parent ID and type
			function getChildNodes(parentId, nodeType) {
				return rawNodes.filter(function(n) {
					return parentMap[n.id] === parentId && n.type === nodeType;
				});
			}
			
			// Helper to get node payload data
			function getPayload(node) {
				return node.data || node.payload || {};
			}
			
			// Helper to safely get approver array from payload
			function getApprovers(payload, field) {
				var val = payload[field];
				if (!val) return [];
				// Handle both arrays and single objects (PowerShell serialization quirk)
				if (Array.isArray(val)) return val;
				if (typeof val === 'object') return [val];
				return [];
			}
			
			// Build hierarchical structure from raw data
			var exportData = {
				metadata: {
					exportDate: new Date().toISOString(),
					totalCatalogs: visibleCatalogIds.length || 0,
					totalPackages: rawNodes.filter(function(n) { return n.type === 'package' && visibleCatalogIds.indexOf(parentMap[n.id]) >= 0; }).length || 0,
					totalPolicies: rawNodes.filter(function(n) { return n.type === 'policy'; }).length || 0,
					totalResources: rawNodes.filter(function(n) { return n.type === 'resource'; }).length || 0,
				totalExtensions: rawNodes.filter(function(n) { return n.type === 'custom-extension'; }).length || 0,
				source: {
					github: "https://github.com/Noble-Effeciency13/M365IdentityPosture",
					psGallery: "https://www.powershellgallery.com/packages/M365IdentityPosture/1.0.0",
					motto: "For the community, by the community"
				},
				createdBy: [
					{
						name: "Sebastian Flæng Markdanner",
						website: "https://chanceofsecurity.com"
					},
					{
						name: "Christian Frohn",
						website: "https://christianfrohn.dk/"
					}
				]
			},
			catalogs: []
		};
		
		// Build catalog data
		visibleCatalogIds.forEach(function(catalogId) {
			var catalogNode = rawNodes.find(function(n) { return n.id === catalogId; });
			if (!catalogNode) return;
			var catalogPayload = getPayload(catalogNode);
			var catalog = {
				id: catalogNode.id,
				name: catalogNode.label,
				description: catalogPayload.description || null,
				catalogType: catalogPayload.catalogType || null,
				state: catalogPayload.state || null,
				isExternallyVisible: catalogPayload.isExternallyVisible,
				accessPackages: []
			};
				
				// Get packages for this catalog
				getChildNodes(catalogNode.id, 'package').forEach(function(packageNode) {
					var packagePayload = getPayload(packageNode);
					var pkg = {
						id: packageNode.id,
						name: packageNode.label,
						description: packagePayload.description || null,
						state: packagePayload.state || null,
						createdDateTime: packagePayload.createdDateTime || null,
						modifiedDateTime: packagePayload.modifiedDateTime || null,
						policies: [],
						resources: []
					};
					
					// Get policies for this package (policies are children of policy-group node)
					var policyGroupNodes = getChildNodes(packageNode.id, 'policy-group');
					if (policyGroupNodes.length > 0) {
						getChildNodes(policyGroupNodes[0].id, 'policy').forEach(function(policyNode) {
							var policyPayload = getPayload(policyNode);
							var policy = {
								id: policyNode.id,
								name: policyNode.label,
								description: policyPayload.description || null,
								audiencePrefix: policyPayload.audiencePrefix || null,
								allowedTargetScope: policyPayload.allowedTargetScope || null,
								specificAllowedTargets: translateApprovers(policyPayload.specificAllowedTargets),
								durationInDays: policyPayload.durationInDays,
								expiration: policyPayload.expiration || null,
								requestorJustificationRequired: policyPayload.requestApprovalSettings?.isRequestorJustificationRequired || false,
								questions: policyPayload.questions || [],
								requestorSettings: policyPayload.requestorSettings || null,
								automaticRequestSettings: policyPayload.automaticRequestSettings || null,
								reviewSettings: policyPayload.reviewSettings ? {
									isEnabled: policyPayload.reviewSettings.isEnabled,
									expirationBehavior: policyPayload.reviewSettings.expirationBehavior || policyPayload.reviewSettings.accessReviewTimeoutBehavior,
									isRecommendationEnabled: policyPayload.reviewSettings.isRecommendationEnabled || policyPayload.reviewSettings.isAccessRecommendationEnabled,
									isReviewerJustificationRequired: policyPayload.reviewSettings.isReviewerJustificationRequired,
									isSelfReview: policyPayload.reviewSettings.isSelfReview,
									schedule: policyPayload.reviewSettings.schedule,
									primaryReviewers: translateApprovers(policyPayload.reviewSettings.primaryReviewers),
									fallbackReviewers: translateApprovers(policyPayload.reviewSettings.fallbackReviewers)
								} : null,
								notificationSettings: policyPayload.notificationSettings || null,
								approvalStages: [],
								customExtensions: []
							};
							
							// Get approval stages for this policy (FROM RAW DATA - this is key!)
						var approvalStages = getChildNodes(policyNode.id, 'approval-stage');
						approvalStages.forEach(function(approvalNode) {
							var approvalPayload = getPayload(approvalNode);
							var primAppr = getApprovers(approvalPayload, 'primaryApprovers');
							var backAppr = getApprovers(approvalPayload, 'backupApprovers');
							var escAppr = getApprovers(approvalPayload, 'escalationApprovers');
							
							var escMinutes = approvalPayload.escalationTimeInMinutes;
							var escDays = approvalPayload.escalationTimeInDays || (escMinutes ? Math.round((escMinutes / 1440) * 100) / 100 : null);
							policy.approvalStages.push({
								name: approvalNode.label,
								primaryApprovers: translateApprovers(primAppr),
								fallbackApprovers: translateApprovers(backAppr),
								alternativeApprovers: translateApprovers(escAppr),
								alternativeTimeInMinutes: escMinutes,
								alternativeTimeInDays: escDays
							});
						});
							
							// Get custom extensions for this policy
							getChildNodes(policyNode.id, 'custom-extension').forEach(function(extensionNode) {
								var extensionPayload = getPayload(extensionNode);
								policy.customExtensions.push({
									name: extensionNode.label,
									stage: extensionPayload.stage || null,
									stageLabel: formatExtensionStage(extensionPayload.stage),
									displayName: extensionPayload.displayName || null
								});
							});
							
							pkg.policies.push(policy);
						});
					}
					
					// Get resources for this package (resources are children of resource-group node)
					var resourceGroupNodes = getChildNodes(packageNode.id, 'resource-group');
					if (resourceGroupNodes.length > 0) {
						getChildNodes(resourceGroupNodes[0].id, 'resource').forEach(function(resourceNode) {
							var resourcePayload = getPayload(resourceNode);
							pkg.resources.push({
								name: resourcePayload.name || resourceNode.label,
								type: resourcePayload.typeLabel || resourcePayload.type,
								originSystem: resourcePayload.originSystem || null,
								originId: resourcePayload.originId || null,
								resourceId: resourcePayload.resourceId || null,
								role: resourcePayload.roleDisplay || null,
								roleId: resourcePayload.roleId || null,
								scope: resourcePayload.scope || null
							});
						});
					}
					
					catalog.accessPackages.push(pkg);
				});
				
				// Get orphaned resources for this catalog
				var orphanedGroupNodes = getChildNodes(catalogNode.id, 'orphaned-group');
				if (orphanedGroupNodes.length > 0) {
					catalog.orphanedResources = [];
					orphanedGroupNodes.forEach(function(orphanedGroup) {
						getChildNodes(orphanedGroup.id, 'orphaned-resource').forEach(function(orphanedNode) {
							var orphanedPayload = getPayload(orphanedNode);
							catalog.orphanedResources.push({
								name: orphanedPayload.name || orphanedNode.label,
								type: orphanedPayload.typeLabel || orphanedPayload.type,
								originSystem: orphanedPayload.originSystem || null,
								originId: orphanedPayload.originId || null,
								resourceId: orphanedPayload.resourceId || null
							});
						});
					});
				}
				
				exportData.catalogs.push(catalog);
			});
			
			// Download JSON with timestamp
			var jsonStr = JSON.stringify(exportData, null, 2);
			var blob = new Blob([jsonStr], { type: 'application/json;charset=utf-8;' });
			var link = document.createElement('a');
			link.href = URL.createObjectURL(blob);
			link.download = 'access-packages-export-' + getTimestamp() + '.json';
			link.click();
		}
		
		function exportMarkdown() {
			// Helper to escape markdown special characters (only backticks and backslashes which break rendering)
			function escapeMarkdown(str) {
				if (!str) return '';
				return String(str).replace(/([\\`])/g, '\\$1');
			}
			
			// Helper to format approver for markdown
			function formatApproverMd(approver) {
				if (!approver || typeof approver !== 'object') return 'Unknown';
				var type = approver['@odata.type'] || '';
				
				if (type === '#microsoft.graph.singleUser') {
					return approver.displayName || approver.userPrincipalName || 'Unknown User';
				} else if (type === '#microsoft.graph.groupMembers') {
					return 'Group: ' + (approver.description || approver.groupId || 'Unknown');
				} else if (type === '#microsoft.graph.requestorManager') {
					return 'Requestor Manager (Level ' + (approver.managerLevel || 1) + ')';
				} else if (type === '#microsoft.graph.internalSponsors') {
					return 'Internal Sponsors';
				} else if (type === '#microsoft.graph.externalSponsors') {
					return 'External Sponsors';
				} else if (type === '#microsoft.graph.targetUserSponsors') {
					return 'Sponsor';
				} else if (type === '#microsoft.graph.attributeRuleMembers') {
					return 'Attribute Rule: ' + (approver.membershipRule || approver.filter || 'N/A');
				}
				return JSON.stringify(approver);
			}
			
			// Use RAW embedded data instead of traversing Cytoscape to ensure complete data
			var rawNodes = data.nodes || [];
			var rawEdges = data.edges || [];
			var visibleCatalogIds = cy.nodes('[type="catalog"]').not('.hidden').map(function(n) { return n.id(); });
			
			// Build parent map from edges (nodes don't have parent property, only edges define relationships)
			var parentMap = {};
			rawEdges.forEach(function(edge) {
				if (edge.source && edge.target) {
					parentMap[edge.target] = edge.source;
				}
			});
			
			// Helper to get child nodes by parent ID and type
			function getChildNodes(parentId, nodeType) {
				return rawNodes.filter(function(n) {
					return parentMap[n.id] === parentId && n.type === nodeType;
				});
			}
			
			// Helper to get node payload data
			function getPayload(node) {
				return node.data || node.payload || {};
			}
			
			// Helper to safely get approver array from payload
			function getApprovers(payload, field) {
				var val = payload[field];
				if (!val) return [];
				// Handle both arrays and single objects (PowerShell serialization quirk)
				if (Array.isArray(val)) return val;
				if (typeof val === 'object') return [val];
				return [];
			}
			
			// Build markdown document
			var md = '# Access Package Documentor Report\n\n';
			md += '**Export Date:** ' + new Date().toISOString() + '\n\n';
			
			// Metadata
			md += '## Summary\n\n';
			md += '| Metric | Count |\n';
			md += '|--------|-------|\n';
			md += '| Catalogs | ' + visibleCatalogIds.length + ' |\n';
			md += '| Access Packages | ' + rawNodes.filter(function(n) { return n.type === 'package' && visibleCatalogIds.indexOf(parentMap[n.id]) >= 0; }).length + ' |\n';
			md += '| Policies | ' + rawNodes.filter(function(n) { return n.type === 'policy'; }).length + ' |\n';
			md += '| Resources | ' + rawNodes.filter(function(n) { return n.type === 'resource'; }).length + ' |\n';
			md += '| Custom Extensions | ' + rawNodes.filter(function(n) { return n.type === 'custom-extension'; }).length + ' |\n';
			md += '\n---\n\n';
			
			// Process each visible catalog from raw data
			rawNodes.filter(function(n) { return n.type === 'catalog' && visibleCatalogIds.indexOf(n.id) >= 0; }).forEach(function(catalogNode) {
				var catalogPayload = getPayload(catalogNode);
				md += '## Catalog: ' + escapeMarkdown(catalogNode.label) + '\n\n';
				if (catalogPayload.description) {
					md += '**Description:** ' + escapeMarkdown(catalogPayload.description) + '\n\n';
				}
				
				// Access Packages in this catalog
				var packageNodes = getChildNodes(catalogNode.id, 'package');
				if (packageNodes.length > 0) {
					md += '### Access Packages (' + packageNodes.length + ')\n\n';
					packageNodes.forEach(function(packageNode) {
						var packagePayload = getPayload(packageNode);
						md += '#### ' + escapeMarkdown(packageNode.label) + '\n\n';
						if (packagePayload.description) {
							md += escapeMarkdown(packagePayload.description) + '\n\n';
						}
						
						// Policies for this package (policies are children of policy-group node)
						var policyGroupNodes = getChildNodes(packageNode.id, 'policy-group');
						var policyNodes = policyGroupNodes.length > 0 ? getChildNodes(policyGroupNodes[0].id, 'policy') : [];
						if (policyNodes.length > 0) {
							md += '##### Policies\n\n';
							policyNodes.forEach(function(policyNode) {
								var policyPayload = getPayload(policyNode);
								md += '**Policy: ' + escapeMarkdown(policyNode.label) + '**\n\n';
								
								if (policyPayload.description) {
									md += '- **Description:** ' + escapeMarkdown(policyPayload.description) + '\n';
								}
								if (policyPayload.audiencePrefix) {
							var audience = policyPayload.audiencePrefix;
							// Remove trailing colon if present
							if (audience.endsWith(':')) audience = audience.slice(0, -1);
							md += '- **Audience:** ' + escapeMarkdown(audience) + '\n';
								}
								if (policyPayload.allowedTargetScope) {
									md += '- **Assigned to:** ' + escapeMarkdown(policyPayload.allowedTargetScope) + '\n';
								}
								if (policyPayload.durationInDays) {
									md += '- **Assignment Duration:** ' + policyPayload.durationInDays + ' days\n';
								}
								if (policyPayload.requestApprovalSettings) {
									md += '- **Requestor Justification Required:** ' + (policyPayload.requestApprovalSettings.isRequestorJustificationRequired ? 'Yes' : 'No') + '\n';
								}
								
								// Approval stages details from RAW DATA
								var approvalNodes = getChildNodes(policyNode.id, 'approval-stage');
								if (approvalNodes.length > 0) {
									md += '\n**Approval Stages:**\n\n';
									approvalNodes.forEach(function(approvalNode, idx) {
						var approvalPayload = getPayload(approvalNode);
md += (idx + 1) + '. **' + escapeMarkdown(approvalNode.label) + '**\n';
										var primaryApprovers = getApprovers(approvalPayload, 'primaryApprovers');
						if (primaryApprovers.length > 0) {
										md += '   - **Primary Approvers:**\n';
										primaryApprovers.forEach(function(appr) {
												md += '      * ' + escapeMarkdown(formatApproverMd(appr)) + '\n';
											});
										}
										var backupApprovers = getApprovers(approvalPayload, 'backupApprovers');
									if (backupApprovers.length > 0) {
										md += '   - **Fallback Approvers:**\n';
										backupApprovers.forEach(function(appr) {
												md += '      * ' + escapeMarkdown(formatApproverMd(appr)) + '\n';
											});
										}
										var escalationApprovers = getApprovers(approvalPayload, 'escalationApprovers');
									if (escalationApprovers.length > 0) {
										md += '   - **Escalation Approvers:**\n';
										escalationApprovers.forEach(function(appr) {
												md += '      * ' + escapeMarkdown(formatApproverMd(appr)) + '\n';
											});
										}
										if (approvalPayload.approvalStageTimeOutInDays) {
											md += '   - Timeout: ' + approvalPayload.approvalStageTimeOutInDays + ' days\n';
										}
										if (approvalPayload.isEscalationEnabled) {
											md += '   - Escalation Enabled: Yes';
											if (approvalPayload.escalationTimeInMinutes) {
												md += ' (after ' + approvalPayload.escalationTimeInMinutes + ' minutes)';
											}
											md += '\n';
										}
										if (approvalPayload.isApproverJustificationRequired) {
											md += '   - Approver Justification Required: Yes\n';
										}
									});
									md += '\n';
								}
								
								// Custom extensions details
								var extensionNodes = getChildNodes(policyNode.id, 'custom-extension');
								if (extensionNodes.length > 0) {
									md += '**Custom Extensions:**\n\n';
									extensionNodes.forEach(function(extensionNode) {
										var extensionPayload = getPayload(extensionNode);
										md += '- ' + escapeMarkdown(extensionNode.label);
										if (extensionPayload.stage) {
											md += ' (Stage: ' + escapeMarkdown(formatExtensionStage(extensionPayload.stage)) + ')';
										}
										md += '\n';
									});
									md += '\n';
								}
								
								md += '---\n\n';
							});
						}
						
						// Resources for this package (resources are children of resource-group node)
						var resourceGroupNodes = getChildNodes(packageNode.id, 'resource-group');
						var resourceNodes = resourceGroupNodes.length > 0 ? getChildNodes(resourceGroupNodes[0].id, 'resource') : [];
						if (resourceNodes.length > 0) {
							md += '##### Resources (' + resourceNodes.length + ')\n\n';
							md += '| Resource | Type | Role |\n';
							md += '|----------|------|------|\n';
							resourceNodes.forEach(function(resourceNode) {
								var resourcePayload = getPayload(resourceNode);
								md += '| ' + escapeMarkdown(resourcePayload.name || resourceNode.label) + 
									  ' | ' + escapeMarkdown(resourcePayload.typeLabel || resourcePayload.type || 'Unknown') +
									  ' | ' + escapeMarkdown(resourcePayload.roleDisplay || 'Unknown') + ' |\n';
							});
							md += '\n';
						}
					});
				}
				
				// Orphaned resources in this catalog
				var orphanedGroupNodes = getChildNodes(catalogNode.id, 'orphaned-group');
				if (orphanedGroupNodes.length > 0) {
					md += '### Orphaned Resources\n\n';
					md += '*Resources in this catalog not assigned to any active access package*\n\n';
					md += '| Resource | Type |\n';
					md +=  '|----------|------|\n';
					orphanedGroupNodes.forEach(function(orphanedGroup) {
						getChildNodes(orphanedGroup.id, 'orphaned-resource').forEach(function(orphanedNode) {
							var orphanedPayload = getPayload(orphanedNode);
							md += '| ' + escapeMarkdown(orphanedPayload.name || orphanedNode.label) + 
								  ' | ' + escapeMarkdown(orphanedPayload.typeLabel || orphanedPayload.type || 'Unknown') + ' |\n';
						});
					});
					md += '\n';
				}
				
				md += '---\n\n';
			});
			
			// Add footer
			md += '\n---\n\n';
			md += '## Report Information\n\n';
			md += '**GitHub:** https://github.com/Noble-Effeciency13/M365IdentityPosture  \n';
			md += '**PSGallery:** https://www.powershellgallery.com/packages/M365IdentityPosture/1.0.0  \n\n';
			md += '*For the community, by the community*\n\n';
			md += '**Created by:**\n';
			md += '- [Sebastian Flæng Markdanner](https://chanceofsecurity.com)  \n';
			md += '- [Christian Frohn](https://christianfrohn.dk/)  \n';
			
			// Download markdown with timestamp
			var blob = new Blob([md], { type: 'text/markdown;charset=utf-8;' });
			var link = document.createElement('a');
			link.href = URL.createObjectURL(blob);
			link.download = 'access-packages-export-' + getTimestamp() + '.md';
			link.click();
		}

		var detailPanel = document.getElementById('details');
		var detailToggle = document.getElementById('details-toggle');
		function setCollapsed(state) {
			detailPanel.classList.toggle('collapsed', state);
			detailToggle.textContent = state ? '▶' : '◀';
		}
		detailToggle.addEventListener('click', function() {
			setCollapsed(!detailPanel.classList.contains('collapsed'));
		});

		function showDetails(label, payloadHtml) {
			document.getElementById('detail-title').textContent = label || 'Details';
			document.getElementById('detail-body').innerHTML = payloadHtml;
			setCollapsed(false);
		}
	})();
	</script>
	<footer>
		<img src="__GITHUB_LOGO__" style="width:14px;height:14px;vertical-align:middle;" alt="GitHub">
		<a href="https://github.com/Noble-Effeciency13/M365IdentityPosture" class="footer-link" target="_blank" rel="noopener">GitHub</a>
		<span class="footer-separator">|</span>
		<img src="__PSGALLERY_LOGO__" style="width:14px;height:14px;vertical-align:middle;" alt="PSGallery">
		<a href="https://www.powershellgallery.com/packages/M365IdentityPosture/1.0.0" class="footer-link" target="_blank" rel="noopener">PSGallery</a>
		<span class="footer-separator">|</span>
		<span class="footer-motto">For the community / By the community</span>
		<span class="footer-separator">|</span>
		<img src="__SEBASTIAN_AVATAR__" style="width:14px;height:14px;vertical-align:middle;border-radius:50%;" alt="Sebastian">
		<span>Sebastian Flæng Markdanner - <a href="https://www.linkedin.com/in/sebastian-markdanner/" class="footer-link" target="_blank" rel="noopener">LinkedIn</a> // <a href="https://chanceofsecurity.com" class="footer-link" target="_blank" rel="noopener">Blog</a></span>
		<span class="footer-separator">|</span>
		<img src="__CHRISTIAN_LOGO__" style="width:14px;height:14px;vertical-align:middle;" alt="Christian">
		<span>Christian Frohn - <a href="https://www.linkedin.com/in/frohn/" class="footer-link" target="_blank" rel="noopener">LinkedIn</a> // <a href="https://christianfrohn.dk/" class="footer-link" target="_blank" rel="noopener">Blog</a></span>
	</footer>
</body>
</html>
'@

	$html = $htmlTemplate.Replace('__DATA_B64__', $jsonBase64).Replace('__THEME__', $Theme).Replace('__GITHUB_LOGO__', $script:GitHubLogo).Replace('__PSGALLERY_LOGO__', $script:PSGalleryLogo).Replace('__SEBASTIAN_AVATAR__', $script:SebastianAvatar).Replace('__CHRISTIAN_LOGO__', $script:ChristianLogo)
	if ($PSCmdlet.ShouldProcess($OutputPath, 'Write access package Documentor HTML')) {
		[System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.Encoding]::UTF8)
	}
	return $OutputPath
}
