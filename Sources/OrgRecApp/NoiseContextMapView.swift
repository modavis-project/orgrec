import OrgRecCore
import SwiftUI
import WebKit

struct NoiseContextMapSheet: View {
    let assessment: NoiseContextAssessment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Surrounding noise context")
                        .japaneseSectionTitle()
                    Text(assessment.venueAnchor.displayAddress)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Planning indicators derived from mapped features—not measured sound levels.")
                        .font(.caption)
                        .foregroundStyle(OrgRecTheme.shu)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(assessment.summary)
                        .font(.caption)
                        .multilineTextAlignment(.trailing)
                    Text(assessment.sourceAttribution)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 380, alignment: .trailing)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider()

            HStack(spacing: 0) {
                NoiseContextWebMap(assessment: assessment)
                    .frame(minWidth: 620, minHeight: 520)

                Divider()

                List(assessment.findings) { finding in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle()
                                .fill(color(for: finding.planningPriority))
                                .frame(width: 8, height: 8)
                            Text(finding.label).font(.callout.bold())
                            Spacer()
                            if let distance = finding.distanceMeters {
                                Text("\(Int(distance.rounded())) m").font(.caption.monospacedDigit())
                            }
                        }
                        Text("\(finding.category.displayName) · \(finding.planningPriority.rawValue.capitalized) priority · \(finding.disposition.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if finding.notes.isEmpty == false {
                            Text(finding.notes).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(width: 340)
            }
        }
        .frame(minWidth: 980, minHeight: 640)
    }

    private func color(for priority: NoisePlanningPriority) -> Color {
        switch priority {
        case .high: OrgRecTheme.shu
        case .medium: OrgRecTheme.ai
        case .low: .secondary
        }
    }
}

private struct NoiseContextWebMap: NSViewRepresentable {
    let assessment: NoiseContextAssessment

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.customUserAgent = "OrgRec/0.1 (pipe-organ recording session planning; macOS)"
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let key = "\(assessment.id.uuidString)-\(assessment.revision)"
        guard context.coordinator.loadedKey != key else { return }
        context.coordinator.loadedKey = key
        webView.loadHTMLString(Self.html(for: assessment), baseURL: URL(string: "https://www.openstreetmap.org"))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedKey: String?
    }

    private struct Payload: Codable {
        struct Point: Codable {
            var latitude: Double
            var longitude: Double
        }

        struct Finding: Codable {
            var id: String
            var label: String
            var category: String
            var priority: String
            var disposition: String
            var distanceMeters: Double?
            var point: Point?
            var geometry: [Point]
        }

        var anchor: Point
        var radiusMeters: Double
        var findings: [Finding]
    }

    private static func html(for assessment: NoiseContextAssessment) -> String {
        let payload = Payload(
            anchor: .init(latitude: assessment.venueAnchor.coordinate.latitude, longitude: assessment.venueAnchor.coordinate.longitude),
            radiusMeters: assessment.radiusMeters,
            findings: assessment.findings.map { finding in
                Payload.Finding(
                    id: finding.id.uuidString,
                    label: finding.label,
                    category: finding.category.displayName,
                    priority: finding.planningPriority.rawValue,
                    disposition: finding.disposition.rawValue,
                    distanceMeters: finding.distanceMeters,
                    point: finding.coordinate.map { .init(latitude: $0.latitude, longitude: $0.longitude) },
                    geometry: finding.geometry.map { .init(latitude: $0.latitude, longitude: $0.longitude) }
                )
            }
        )
        let data = (try? JSONEncoder().encode(payload)) ?? Data("{}".utf8)
        let encoded = data.base64EncodedString()
        return """
        <!doctype html>
        <html><head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width,initial-scale=1" />
          <link href="https://unpkg.com/maplibre-gl@5.6.2/dist/maplibre-gl.css" rel="stylesheet" />
          <style>
            html,body,#map { width:100%; height:100%; margin:0; background:#eee9de; }
            .maplibregl-popup-content { font: 12px -apple-system,BlinkMacSystemFont,sans-serif; max-width:280px; }
            #fallback { position:absolute; z-index:10; inset:16px auto auto 16px; padding:9px 12px; background:rgba(251,249,243,.94); border-radius:6px; font:12px -apple-system; display:none; }
          </style>
        </head><body>
          <div id="map"></div><div id="fallback">The map tiles are unavailable. The saved assessment and findings remain accessible in OrgRec.</div>
          <script src="https://unpkg.com/maplibre-gl@5.6.2/dist/maplibre-gl.js"></script>
          <script>
            const bytes = Uint8Array.from(atob('\(encoded)'), c => c.charCodeAt(0));
            const payload = JSON.parse(new TextDecoder().decode(bytes));
            if (!window.maplibregl) document.getElementById('fallback').style.display='block';
            else {
              const center = [payload.anchor.longitude, payload.anchor.latitude];
              const map = new maplibregl.Map({
                container:'map', center:center, zoom:15,
                style:{version:8,sources:{osm:{type:'raster',tiles:['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],tileSize:256,attribution:'© OpenStreetMap contributors'}},layers:[{id:'osm',type:'raster',source:'osm'}]},
                attributionControl:true
              });
              map.addControl(new maplibregl.NavigationControl({showCompass:false}),'top-right');
              map.on('error', () => { document.getElementById('fallback').style.display='block'; });
              map.on('load', () => {
                const ring=[]; const steps=96; const earth=6378137;
                for(let i=0;i<=steps;i++) { const b=2*Math.PI*i/steps; const dy=payload.radiusMeters*Math.cos(b); const dx=payload.radiusMeters*Math.sin(b); ring.push([center[0]+dx/(earth*Math.cos(center[1]*Math.PI/180))*180/Math.PI,center[1]+dy/earth*180/Math.PI]); }
                map.addSource('radius',{type:'geojson',data:{type:'Feature',geometry:{type:'Polygon',coordinates:[ring]}}});
                map.addLayer({id:'radius-fill',type:'fill',source:'radius',paint:{'fill-color':'#365d68','fill-opacity':.08}});
                map.addLayer({id:'radius-line',type:'line',source:'radius',paint:{'line-color':'#365d68','line-width':2,'line-dasharray':[3,2]}});
                const features=[];
                payload.findings.forEach(f => {
                  const props={id:f.id,label:f.label,category:f.category,priority:f.priority,disposition:f.disposition,distanceMeters:f.distanceMeters};
                  if(f.geometry.length>1) features.push({type:'Feature',properties:props,geometry:{type:'LineString',coordinates:f.geometry.map(p=>[p.longitude,p.latitude])}});
                  const p=f.point || f.geometry[0]; if(p) features.push({type:'Feature',properties:props,geometry:{type:'Point',coordinates:[p.longitude,p.latitude]}});
                });
                map.addSource('findings',{type:'geojson',data:{type:'FeatureCollection',features}});
                map.addLayer({id:'finding-lines',type:'line',source:'findings',filter:['==',['geometry-type'],'LineString'],paint:{'line-color':['match',['get','priority'],'high','#b94732','medium','#365d68','#777'], 'line-width':3,'line-opacity':.8}});
                map.addLayer({id:'finding-points',type:'circle',source:'findings',filter:['==',['geometry-type'],'Point'],paint:{'circle-radius':7,'circle-color':['match',['get','priority'],'high','#b94732','medium','#365d68','#777'],'circle-stroke-color':'#fbf9f3','circle-stroke-width':2}});
                new maplibregl.Marker({color:'#252521'}).setLngLat(center).setPopup(new maplibregl.Popup().setText('Confirmed organ venue')).addTo(map);
                map.on('click','finding-points',e=>{ const f=e.features[0]; const d=f.properties.distanceMeters ? ` · ${Math.round(f.properties.distanceMeters)} m` : ''; const box=document.createElement('div'); const heading=document.createElement('strong'); heading.textContent=f.properties.label; box.appendChild(heading); box.appendChild(document.createElement('br')); box.appendChild(document.createTextNode(`${f.properties.category} · ${f.properties.priority} priority${d}`)); box.appendChild(document.createElement('br')); box.appendChild(document.createTextNode(`Review: ${f.properties.disposition}`)); new maplibregl.Popup().setLngLat(e.lngLat).setDOMContent(box).addTo(map); });
                map.on('mouseenter','finding-points',()=>map.getCanvas().style.cursor='pointer');
                map.on('mouseleave','finding-points',()=>map.getCanvas().style.cursor='');
              });
            }
          </script>
        </body></html>
        """
    }
}
