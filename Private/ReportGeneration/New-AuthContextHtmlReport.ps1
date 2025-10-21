function New-AuthContextHtmlReport {
	<#
	.SYNOPSIS
		Builds a static HTML report consolidating all Authentication Context usage artifacts.

	.DESCRIPTION
		Accepts pre-collected dataset objects (contexts, labels, sites, groups, CA policies, protected actions, and PIM
		outputs) and produces a self-contained HTML (no interactive JS) summarizing KPIs plus tabular sections. Sanitizes
		auth context identifier columns to remove stray quotes introduced by serialization edge cases.

	.PARAMETER AuthContexts
		Authentication context objects (Id, DisplayName,...).

	.PARAMETER Labels
		Sensitivity labels with potential Authentication Context bindings.

	.PARAMETER Sites
		SharePoint site objects carrying auth context references.

	.PARAMETER Groups
    	Unified / security group objects (already filtered where relevant).

	.PARAMETER CA
		Conditional Access policy summary rows from Get-ConditionalAccessPoliciesWithAuthContext.

	.PARAMETER ProtectedActions
		Action rows from Get-ProtectedActionsWithAuthContext.

	.PARAMETER PIMPoliciesEntra
		Normalized Entra (directory) PIM policy rows.

	.PARAMETER PIMPoliciesGroups
		Normalized group-scope PIM policy rows.

	.PARAMETER PIMPoliciesAzureResources
		Normalized Azure resource PIM policy rows.

	.PARAMETER Path
		Destination file path (HTML). If omitted, output object is returned and no file written.

	.PARAMETER QuietMode
		Suppresses non-error host output.

	.OUTPUTS
		String (path) when -Path supplied; otherwise PSCustomObject representing report metadata/content.

	.NOTES
		Designed for portability; tables rely on basic HTML/CSS only.

	.EXAMPLE
		New-AuthContextHtmlReport -AuthContexts $ac -Labels $lbl -Sites $sites -Groups $grps -CA $ca -ProtectedActions $pa -PIMPoliciesEntra $pimE -PIMPoliciesGroups $pimG -PIMPoliciesAzureResources $pimAz -Path report.html
	#>
	[CmdletBinding()] param(
		[Parameter(Mandatory)][object]$AuthContexts,
		[Parameter(Mandatory)][object]$Labels,
		[Parameter(Mandatory)][object]$Sites,
		[Parameter(Mandatory)][object]$Groups,
		[object]$CA,
		[object]$ProtectedActions,
		[object]$PIMPoliciesEntra,
		[object]$PIMPoliciesGroups,
		[object]$PIMPoliciesAzureResources,
		[string]$Path,
		[ValidateSet('Classic', 'Dark')][string]$Style = 'Classic',
		[ValidateSet('Classic', 'Tabbed', 'TabbedOverview', 'Sidebar', 'Masonry', 'Dashboard', 'Layoutv2')][string]$Layout = 'TabbedOverview',
		[switch]$GenerateAllThemesForLayout,
		[switch]$QuietMode
	)

	$Sites = SanitizeAuthContextText $Sites
	$Groups = SanitizeAuthContextText $Groups
	$CA = SanitizeAuthContextText $CA
	$ProtectedActions = SanitizeAuthContextText $ProtectedActions
	$PIMPoliciesEntra = SanitizeAuthContextText $PIMPoliciesEntra
	$PIMPoliciesGroups = SanitizeAuthContextText $PIMPoliciesGroups
	$PIMPoliciesAzureResources = SanitizeAuthContextText $PIMPoliciesAzureResources

	$kpi = [pscustomobject]@{
		'Authentication Contexts'          = ($AuthContexts | Measure-Object).Count
		'Sensitivity Labels'               = ($Labels | Measure-Object).Count
		'SharePoint Sites'                 = ($Sites | Measure-Object).Count
		'Security Groups'                  = ($Groups | Measure-Object).Count
		'Conditional Access Policies'      = ($CA | Measure-Object).Count
		'Protected Actions'                = ($ProtectedActions | Measure-Object).Count
		'PIM Policies for Entra'           = ($PIMPoliciesEntra | Measure-Object).Count
		'PIM Policies for Groups'          = ($PIMPoliciesGroups | Measure-Object).Count
		'PIM Policies for Azure Resources' = ($PIMPoliciesAzureResources | Measure-Object).Count
	}
  
	$ts = Get-Date
	$sections = @(
		@{Title = 'Authentication Contexts'; Data = $AuthContexts },
		@{Title = 'Sensitivity Labels'; Data = $Labels },
		@{Title = 'SharePoint Sites'; Data = $Sites },
		@{Title = 'Security Groups'; Data = $Groups },
		@{Title = 'Conditional Access Policies'; Data = $CA },
		@{Title = 'Protected Actions'; Data = $ProtectedActions },
		@{Title = 'PIM Policies for Entra'; Data = $PIMPoliciesEntra },
		@{Title = 'PIM Policies for Groups'; Data = $PIMPoliciesGroups },
		@{Title = 'PIM Policies for Azure Resources'; Data = $PIMPoliciesAzureResources }
	)
	# Dual-mode CSS (Classic light & Dark) via CSS variables
	$css = 'body{font-family:Segoe UI,Arial,sans-serif;margin:0;--bg:#f5f7fa;--text:#222;--panel:#fff;--panel-border:#e2e7ef;--accent:#0f4c81;--muted:#555;--hover:#f9fcff;--kpi-bg:#fff;--footer:#666;background:var(--bg);color:var(--text)}body.dark-mode{--bg:#1e1f24;--text:#e6e6e6;--panel:#26282e;--panel-border:#3b3d44;--accent:#4da3ff;--muted:#9aa4b1;--hover:#31343a;--kpi-bg:#2b2d33;--footer:#9aa4b1}header{background:var(--accent);color:#fff;padding:18px 28px;display:flex;align-items:center;gap:16px}header h1{margin:0;font-size:22px;flex:1}button.theme-toggle{background:#fff;color:var(--accent);border:1px solid var(--accent);padding:6px 12px;border-radius:6px;cursor:pointer;font-size:12px;font-weight:600}body.dark-mode button.theme-toggle{background:#2b2d33;color:var(--accent);border-color:#2b2d33}.kpis{display:flex;flex-wrap:wrap;margin:20px}.kpi{background:var(--kpi-bg);border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,.08);padding:14px 18px;margin:8px;flex:1 1 160px;min-width:160px}.kpi h3{margin:0 0 6px;font-size:12px;font-weight:600;text-transform:uppercase;color:var(--muted)}.kpi .val{font-size:26px;font-weight:600;color:var(--accent)}section{margin:25px 28px;background:var(--panel);padding:18px 22px 28px;border-radius:10px;box-shadow:0 2px 6px rgba(0,0,0,.08)}section h2{margin:0 0 10px;font-size:18px;color:var(--accent);display:flex;align-items:center;cursor:pointer}section h2 .chevron{margin-left:8px;transition:transform .25s}section.collapsed .chevron{transform:rotate(-90deg)}table{border-collapse:collapse;width:100%;margin-top:12px;font-size:13px}th,td{text-align:left;padding:6px 8px;border-bottom:1px solid var(--panel-border)}th{background:color-mix(in srgb,var(--accent) 15%,#fff);cursor:pointer;position:relative}body.dark-mode th{background:#30333a;color:#cdd3db}th.sort-asc::after,th.sort-desc::after{content:"";border:5px solid transparent;position:absolute;right:8px;top:50%;transform:translateY(-50%)}th.sort-asc::after{border-bottom-color:var(--accent);margin-top:-6px}th.sort-desc::after{border-top-color:var(--accent);margin-top:4px}tr:hover{background:var(--hover)}footer{margin:40px 0 0;padding:20px 28px;font-size:11px;color:var(--footer);text-align:center}body.dark-mode .tab-button{color:#e6e6e6}body.dark-mode .tab-button.active{color:#fff}body.dark-mode .tab-pane h2{color:var(--accent)}body.dark-mode .overview-stack h3{color:#cdd3db}'

	# Build JS bundle depending on layout
	$jsCommon = @()
	$jsCommon += 'function sortTable(t,idx){const tbody=t.tBodies[0];const rows=[...tbody.querySelectorAll("tr")];const th=t.tHead.rows[0].cells[idx];const asc=!th.classList.contains("sort-asc");[...t.tHead.rows[0].cells].forEach(h=>h.classList.remove("sort-asc","sort-desc"));th.classList.add(asc?"sort-asc":"sort-desc");rows.sort((a,b)=>{const ta=a.cells[idx].innerText||"";const tb=b.cells[idx].innerText||"";const na=parseFloat(ta.replace(/[^0-9.-]/g,""));const nb=parseFloat(tb.replace(/[^0-9.-]/g,""));if(!isNaN(na)&&!isNaN(nb)){return asc?na-nb:nb-na}return asc?ta.localeCompare(tb):tb.localeCompare(ta);});rows.forEach(r=>tbody.appendChild(r));}'
	switch ($Layout) {
		'Classic' { $jsCommon += 'document.querySelectorAll("th").forEach((th,i)=>th.addEventListener("click",()=>sortTable(th.closest("table"),i)));document.querySelectorAll("section h2").forEach(h=>h.addEventListener("click",()=>h.parentElement.classList.toggle("collapsed")));' }
		'Tabbed' { $jsCommon += 'document.querySelectorAll("th").forEach((th,i)=>th.addEventListener("click",()=>sortTable(th.closest("table"),i)));const tabs=[...document.querySelectorAll(".tab-button")];const panes=[...document.querySelectorAll(".tab-pane")];tabs.forEach(tb=>tb.addEventListener("click",()=>{tabs.forEach(t=>t.classList.remove("active"));tb.classList.add("active");panes.forEach(p=>p.classList.toggle("active",p.dataset.pid===tb.dataset.pid));}));if(tabs.length>0){tabs[0].click();}' }
		'TabbedOverview' { $jsCommon += 'document.querySelectorAll("th").forEach((th,i)=>th.addEventListener("click",()=>sortTable(th.closest("table"),i)));const tabs=[...document.querySelectorAll(".tab-button")];const panes=[...document.querySelectorAll(".tab-pane")];tabs.forEach(tb=>tb.addEventListener("click",()=>{tabs.forEach(t=>t.classList.remove("active"));tb.classList.add("active");panes.forEach(p=>p.classList.toggle("active",p.dataset.pid===tb.dataset.pid));}));if(tabs.length>0){tabs[0].click();}' }
		'Sidebar' { $jsCommon += 'document.querySelectorAll("th").forEach((th,i)=>th.addEventListener("click",()=>sortTable(th.closest("table"),i)));document.querySelectorAll("section h2").forEach(h=>h.addEventListener("click",()=>h.parentElement.classList.toggle("collapsed")));' }
		'Masonry' { $jsCommon += 'document.querySelectorAll("th").forEach((th,i)=>th.addEventListener("click",()=>sortTable(th.closest("table"),i)));document.querySelectorAll("section h2").forEach(h=>h.addEventListener("click",()=>h.parentElement.classList.toggle("collapsed")));' }
		'Dashboard' { $jsCommon += 'document.querySelectorAll(".detail-open").forEach(btn=>btn.addEventListener("click",()=>{const id=btn.dataset.target;document.getElementById(id).classList.add("show");document.body.classList.add("modal-open");}));document.querySelectorAll(".modal .close").forEach(btn=>btn.addEventListener("click",()=>{btn.closest(".modal").classList.remove("show");document.body.classList.remove("modal-open");}));document.querySelectorAll("th").forEach((th,i)=>th.addEventListener("click",()=>sortTable(th.closest("table"),i)));' }
		'Layoutv2' { $jsCommon += 'document.querySelectorAll("th").forEach((th,i)=>th.addEventListener("click",()=>sortTable(th.closest("table"),i)));const g=document.getElementById("globalSearch");if(g){g.addEventListener("input",()=>{const q=g.value.toLowerCase();document.querySelectorAll("table tbody tr").forEach(r=>{const t=r.innerText.toLowerCase();r.style.display=t.indexOf(q)>-1?"":"none";});});}document.querySelectorAll(".collapse-btn").forEach(btn=>btn.addEventListener("click",()=>{const card=btn.closest(".lv2-card");card.classList.toggle("collapsed");btn.textContent=card.classList.contains("collapsed")?"+":"−";}));' }
	}
	$jsBundleCore = ($jsCommon -join '')
	$jsBundle = 'document.addEventListener("DOMContentLoaded",()=>{' + $jsBundleCore + 'const tg=document.getElementById("themeToggle");if(tg){tg.addEventListener("click",()=>{document.body.classList.toggle("dark-mode");tg.textContent=document.body.classList.contains("dark-mode")?"Light Mode":"Dark Mode";});if("' + $Style + '"==="Dark"){document.body.classList.add("dark-mode");tg.textContent="Light Mode";}}});'
	$scriptTag = '<script>' + $jsBundle + '</script>'

	# Layout-specific CSS extension
	$layoutCss = switch ($Layout) {
		'Classic' { '' }
  'Tabbed' { '.tabs{margin:0 40px}.tab-list{display:flex;flex-wrap:wrap;gap:8px;margin:20px 0}.tab-button{background:var(--panel);border:1px solid var(--panel-border);border-radius:20px;padding:8px 14px;font-size:13px;cursor:pointer;transition:.2s}.tab-button.active{background:var(--accent);color:#fff}.tab-pane{display:none}.tab-pane.active{display:block}' }
  'TabbedOverview' { '.tabs{margin:0 40px}.tab-list{display:flex;flex-wrap:wrap;gap:8px;margin:20px 0}.tab-button{background:var(--panel);border:1px solid var(--panel-border);border-radius:20px;padding:8px 14px;font-size:13px;cursor:pointer;transition:.2s}.tab-button.active{background:var(--accent);color:#fff}.tab-pane{display:none}.tab-pane.active{display:block}.overview-stack .ov-section{margin:22px 0;padding:14px 18px;border:1px solid var(--panel-border);border-radius:10px;background:var(--panel)}' }
		'Sidebar' { 'body{display:flex}aside.nav{width:240px;background:#103c64;color:#fff;min-height:100vh;padding:28px 20px;box-shadow:2px 0 6px rgba(0,0,0,.15)}aside.nav h2{margin:0 0 16px;font-size:18px}aside.nav a{display:block;color:#fff;text-decoration:none;padding:6px 10px;border-radius:6px;margin-bottom:4px;font-size:13px}aside.nav a:hover{background:#1d5795}main.report{flex:1}main.report .kpis{margin:26px 40px}main.report section{margin:26px 40px}' }
		'Masonry' { '.masonry{columns:3;column-gap:18px;margin:0 30px 40px}@media(max-width:1300px){.masonry{columns:2}}@media(max-width:900px){.masonry{columns:1}}.masonry section{display:inline-block;width:100%;margin:0 0 18px;break-inside:avoid}' }
		'Dashboard' { '.grid-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:18px;margin:30px 40px}.card{background:#fff;border-radius:14px;padding:20px 22px;box-shadow:0 4px 12px rgba(0,0,0,.08);position:relative;overflow:hidden}.card h3{margin:0 0 10px;font-size:14px;text-transform:uppercase;color:#536b85}.card .num{font-size:38px;font-weight:700;color:#103c64;margin:0 0 14px}.card button{background:#103c64;color:#fff;border:none;padding:8px 14px;border-radius:6px;cursor:pointer;font-size:12px}.card button:hover{background:#0d3350}.modal{position:fixed;left:0;top:0;width:100%;height:100%;background:rgba(0,0,0,.55);display:none;align-items:flex-start;overflow:auto;padding:60px 40px 40px;z-index:1000}.modal.show{display:flex}.modal .content{background:#fff;border-radius:16px;padding:30px 34px;max-width:1200px;width:100%;box-shadow:0 6px 18px rgba(0,0,0,.25)}.modal .close{float:right;font-size:16px;font-weight:600;background:#eee;border:none;padding:4px 10px;border-radius:6px;cursor:pointer;margin:-8px -8px 10px 0}body.modal-open{overflow:hidden}' }
		'Layoutv2' { 'body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:linear-gradient(120deg,#eef2f7,#dde7f3,#f4f7fa);color:#1d2935}header{backdrop-filter:blur(6px);background:rgba(16,60,100,.85);color:#fff;padding:26px 42px;position:sticky;top:0;z-index:500;box-shadow:0 4px 16px rgba(0,0,0,.25)}header h1{margin:0;font-size:26px;letter-spacing:.5px}.lv2-kpi-bar{display:flex;flex-wrap:wrap;gap:14px;margin:26px 42px}.lv2-kpi{flex:1 1 180px;background:rgba(255,255,255,.75);backdrop-filter:blur(4px);border-radius:14px;padding:14px 18px;box-shadow:0 2px 6px rgba(0,0,0,.12)}.lv2-kpi .kpi-label{display:block;font-size:11px;font-weight:600;text-transform:uppercase;color:#4e6075}.lv2-kpi .kpi-value{font-size:28px;font-weight:600;color:#103c64}.lv2-container{margin:10px 42px 60px}.lv2-search{margin:0 0 24px;display:flex;justify-content:flex-end}.lv2-search input{width:320px;padding:10px 14px;border:1px solid #b8c7d6;border-radius:10px;font-size:14px;box-shadow:0 1px 3px rgba(0,0,0,.1)}.lv2-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(380px,1fr));gap:22px}.lv2-card{background:rgba(255,255,255,.7);backdrop-filter:blur(4px);border-radius:18px;box-shadow:0 8px 24px -6px rgba(0,0,0,.18);display:flex;flex-direction:column;overflow:hidden;transition:.25s}.lv2-card:hover{transform:translateY(-4px);box-shadow:0 12px 32px -6px rgba(0,0,0,.22)}.lv2-card-head{display:flex;align-items:center;gap:14px;padding:16px 20px;border-bottom:1px solid #d6e1ec;background:linear-gradient(90deg,#ffffff,#f5f9fc)}.lv2-card-head h2{flex:1;margin:0;font-size:18px;color:#103c64}.count-badge{background:#103c64;color:#fff;padding:4px 10px;border-radius:20px;font-size:12px;font-weight:600}.collapse-btn{background:#103c64;color:#fff;border:none;padding:6px 10px;border-radius:8px;cursor:pointer;font-size:12px}.collapse-btn:hover{background:#0d3350}.lv2-card-body{padding:16px 20px;max-height:640px;overflow:auto}.lv2-card.collapsed .lv2-card-body{display:none}.lv2-card.collapsed .collapse-btn{background:#607a94}.lv2-card table{font-size:12px}footer{margin:60px 0 0;padding:30px 42px;font-size:12px;color:#455869;text-align:center}.sticky-search-shadow{box-shadow:0 4px 12px -3px rgba(0,0,0,.28)}' }
	}
	$css = $css + $layoutCss

	# Pre-render section contents
	$sectionHtmlBlocks = foreach ($reportSection in $sections) { Convert-DataTableHtml -Data $reportSection.Data -Title $reportSection.Title }
	$htmlHeader = '<!DOCTYPE html><html><head><meta charset="utf-8" /><title>Authentication Context Inventory</title><meta name="viewport" content="width=device-width,initial-scale=1" /><style>' + $css + '</style>' + $scriptTag + '</head><body>'
	$headerBlock = '<header><h1>Authentication Context Inventory</h1><button id="themeToggle" class="theme-toggle" type="button">' + ($Style -eq 'Dark' ? 'Light Mode' : 'Dark Mode') + '</button></header>'
	$kpiBlock = '<div class="kpis">' + (($kpi.PSObject.Properties | ForEach-Object { "<div class='kpi'><h3>$($_.Name)</h3><div class='val'>$($_.Value)</div></div>" }) -join '') + '</div>'
	switch ($Layout) {
		'Classic' {
			$bodyBlock = ($sections | ForEach-Object -Begin { $acc = @() } -Process { $acc += "<section><h2>$($_.Title)<span class='chevron'>▶</span></h2>$($sectionHtmlBlocks[$acc.Count])</section>" } -End { $acc -join '' })
		}
		'Tabbed' {
			$tabButtons = ($sections | ForEach-Object -Begin { $i = 0; $btns = @() } -Process { $btns += "<button class='tab-button' data-pid='pane$i'>$($_.Title)</button>"; $i++ } -End { $btns -join '' })
			$tabPanes = ($sections | ForEach-Object -Begin { $j = 0; $panes = @() } -Process { $panes += "<div class='tab-pane' data-pid='pane$j'><h2>$($_.Title)</h2>$($sectionHtmlBlocks[$j])</div>"; $j++ } -End { $panes -join '' })
			$bodyBlock = "<div class='tabs'><div class='tab-list'>$tabButtons</div>$tabPanes</div>"
		}
		'TabbedOverview' {
			$overviewContent = ($sections | ForEach-Object -Begin { $o = @() } -Process { $o += "<div class='ov-section'><h3>$($_.Title)</h3>$($sectionHtmlBlocks[$o.Count])</div>" } -End { $o -join '' })
			$tabButtons = '<button class="tab-button" data-pid="paneOverview">Overview</button>' + ($sections | ForEach-Object -Begin { $i = 0; $btns = @() } -Process { $btns += "<button class='tab-button' data-pid='pane$i'>$($_.Title)</button>"; $i++ } -End { $btns -join '' })
			$tabPanesOverview = "<div class='tab-pane overview-pane' data-pid='paneOverview'><h2>Overview</h2>$kpiBlock<div class='overview-stack'>$overviewContent</div></div>"
			$tabPanesSections = ($sections | ForEach-Object -Begin { $j = 0; $panes = @() } -Process { $panes += "<div class='tab-pane' data-pid='pane$j'><h2>$($_.Title)</h2>$($sectionHtmlBlocks[$j])</div>"; $j++ } -End { $panes -join '' })
			$bodyBlock = "<div class='tabs'><div class='tab-list'>$tabButtons</div>$tabPanesOverview$tabPanesSections</div>"
			$kpiBlock = ''
		}
		'Sidebar' {
			$navLinks = ($sections | ForEach-Object -Begin { $x = 0; $links = @() } -Process { $links += "<a href='#sec$x'>$($_.Title)</a>"; $x++ } -End { $links -join '' })
			$contentSections = ($sections | ForEach-Object -Begin { $y = 0; $secs = @() } -Process { $secs += "<section id='sec$y'><h2>$($_.Title)<span class='chevron'>▶</span></h2>$($sectionHtmlBlocks[$y])</section>"; $y++ } -End { $secs -join '' })
			$bodyBlock = "<aside class='nav'><h2>Sections</h2>$navLinks</aside><main class='report'>$kpiBlock$contentSections</main>"; $kpiBlock = ''
		}
		'Masonry' {
			$masonrySections = ($sections | ForEach-Object -Begin { $z = 0; $cards = @() } -Process { $cards += "<section><h2>$($_.Title)<span class='chevron'>▶</span></h2>$($sectionHtmlBlocks[$z])</section>"; $z++ } -End { $cards -join '' })
			$bodyBlock = "<div class='masonry'>$masonrySections</div>"
		}
		'Dashboard' {
			$cards = ($sections | ForEach-Object -Begin { $d = 0; $c = @() } -Process { $countVal = ($sections[$d].Data | Measure-Object).Count; $modalId = "modal$d"; $c += "<div class='card'><h3>$($_.Title)</h3><div class='num'>$countVal</div><button class='detail-open' data-target='$modalId'>Details</button></div>"; $d++ } -End { $c -join '' })
			$modals = ($sections | ForEach-Object -Begin { $e = 0; $m = @() } -Process { $m += "<div class='modal' id='modal$e'><div class='content'><button class='close' aria-label='Close'>&times;</button><h2>$($_.Title)</h2>$($sectionHtmlBlocks[$e])</div></div>"; $e++ } -End { $m -join '' })
			$bodyBlock = "<div class='grid-cards'>$cards</div>$modals"; $kpiBlock = ''
		}
		'Layoutv2' {
			$kpiBlock = '<div class="lv2-kpi-bar">' + (($kpi.PSObject.Properties | ForEach-Object { "<div class='lv2-kpi'><span class='kpi-label'>$($_.Name)</span><span class='kpi-value'>$($_.Value)</span></div>" }) -join '') + '</div>'
			$searchBar = '<div class="lv2-search"><input type="text" id="globalSearch" placeholder="Search all tables..." aria-label="Global search" /></div>'
			$sectionBlocks = ($sections | ForEach-Object -Begin { $i2 = 0; $b = @() } -Process { $countVal = ($sections[$i2].Data | Measure-Object).Count; $b += "<div class='lv2-card' data-card-index='$i2'><div class='lv2-card-head'><h2>$($_.Title)</h2><span class='count-badge'>$countVal</span><button class='collapse-btn' aria-label='Toggle section'>−</button></div><div class='lv2-card-body'>$($sectionHtmlBlocks[$i2])</div></div>"; $i2++ } -End { $b -join '' })
			$bodyBlock = "<div class='lv2-container'>$searchBar<div class='lv2-grid'>$sectionBlocks</div></div>"
		}
	}
	$footerBlock = "<footer>Generated $($ts.ToString('dd-MM-yyyy')) by Authentication Context Inventory Script v$script:ToolVersion<br>By Sebastian Flæng Markdanner @Chanceofsecurity.com — Style: $Style — Layout: $Layout</footer>"
	$finalHtml = $htmlHeader + $headerBlock + $kpiBlock + $bodyBlock + $footerBlock + '</body></html>'

	if ($GenerateAllThemesForLayout) {
		$base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
		$dir = [System.IO.Path]::GetDirectoryName($Path)
		foreach ($theme in 'Default', 'Minimal', 'Dark', 'Compact', 'Accessible', 'Cards') {
			$themePath = Join-Path $dir ($base + '_' + $Layout + '_' + $theme + '.html')
			if (-not $QuietMode) { Write-Host "[Report] Generating variant: Layout=$Layout Theme=$theme -> $themePath" -ForegroundColor DarkCyan }
			New-AuthContextHtmlReport -AuthContexts $AuthContexts -Labels $Labels -Sites $Sites -Groups $Groups -CA $CA -ProtectedActions $ProtectedActions -PIMPoliciesEntra $PIMPoliciesEntra -PIMPoliciesGroups $PIMPoliciesGroups -PIMPoliciesAzureResources $PIMPoliciesAzureResources -Path $themePath -Style $theme -Layout $Layout -QuietMode:$QuietMode | Out-Null
		}
	}

	Set-Content -Path $Path -Value $finalHtml -Encoding UTF8
	return $Path
}
