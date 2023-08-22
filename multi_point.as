// Documentation available at https://donadigo.com/tminterface/plugins/api


float eval_min;
float eval_max;
float num_points;
string raw_points;
array<vec3> final_points;
bool verbose;
vec3 carpos;

void RenderEvalSettings()
{
    GetVariable("multi_point_min_eval", eval_min);
    GetVariable("multi_point_max_eval", eval_max);
    GetVariable("multi_point_points", raw_points);
    GetVariable("multi_point_num", num_points);
    GetRawPoints();

    UI::Dummy(vec2(0, 5));
    UI::InputTimeVar("Eval min", "multi_point_min_eval");
    UI::InputTimeVar("Eval max", "multi_point_max_eval");

    UI::Dummy(vec2(0, 5));
    UI::CheckboxVar("Verbose", "multi_point_verbose");
    UI::TextDimmed("If enabled, the bruteforce window will tell you more information about improvements");

    UI::Dummy(vec2(0, 5));
    UI::Text("Points:");
    for (int i = 0; i < num_points; i++) {
        RegisterVariable("multi_point_" + Text::FormatInt(i), "0 0 0");
        UI::DragFloat3Var("Point " + Text::FormatInt(i), "multi_point_" + Text::FormatInt(i));
        UI::SameLine();
        if (UI::Button("Copy cam to point " + Text::FormatInt(i))) {
            auto cam = GetCurrentCamera();
            if (@cam != null) {
                SetVariable("multi_point_" + Text::FormatInt(i), cam.Location.Position.ToString());
        }
        }
        UI::SameLine();
        if (UI::Button("Remove point " + Text::FormatInt(i))) {
            SetVariable("multi_point_" + Text::FormatInt(i), "");
            GetRawPoints();
            SetVariable("multi_point_num", --num_points);
            SetEachPoint();
        }
    }

    if (UI::Button("Add point")) {
        SetVariable("multi_point_num", ++num_points);
        RegisterVariable("multi_point_" + Text::FormatInt(num_points - 1), "0 0 0");
        SetVariable("multi_point_" + Text::FormatFloat(num_points - 1), "0 0 0");
    }

    UI::SameLine();
    if (UI::Button("Remove all")) {
        int temp = num_points;
        for (int teh = 0; teh < temp; teh++) {
            SetVariable("multi_point_" + Text::FormatInt(teh), "");
            GetRawPoints();
            SetVariable("multi_point_num", --num_points);
            SetEachPoint();
        }
    }

}

array<float> best;
array<float> current;
int time = -1;
BFEvaluationResponse@ OnEvaluate(SimulationManager@ simManager, const BFEvaluationInfo&in info)
{
    int raceTime = simManager.RaceTime;

    auto resp = BFEvaluationResponse();
    if (info.Rewinded) {
        ReInitCurrent();
    }

    bool isbetter = is_better(simManager);

    if (info.Phase == BFPhase::Initial) {
        if (eval_min <= raceTime and raceTime <= eval_max and isbetter) {
            best = current;
            time = raceTime;
        }
        if (raceTime == eval_max) {
            if (final_points.Length != 0) {
                if (GetB("multi_point_verbose")) {
                    print("Best at iteration " + info.Iterations + ":");
                    print("Distance from");
                    for (int k = 0; k < int(final_points.Length); k++) {
                        print("Point " + k + ": " + best[k]);
                    }
                    print("Total : " + SumArrayElements(best));
                    print("");
                }
                else {
                    print("Best at iteration " + info.Iterations + ": " + SumArrayElements(best));
                }
            }
            else {
                print("NO POINTS PLACED", Severity::Error);
            }
        }
    } else if (info.Phase == BFPhase::Search) {
        if (eval_min <= raceTime and raceTime <= eval_max and isbetter) {
            resp.Decision = BFEvaluationDecision::Accept;
        }
        if (eval_max <= raceTime) {
            if (resp.Decision != BFEvaluationDecision::Accept) {
                resp.Decision = BFEvaluationDecision::Reject;
            }
        }
    }

    return resp;
}

bool is_better(SimulationManager@ sim_manager) {

    auto state = sim_manager.Dyna.CurrentState;
    auto pos = state.Location.Position;

    for (int idx = 0; idx < int(final_points.Length); idx++) {
        float dist = Math::Distance(pos, final_points[idx]);
        if (dist < current[idx]) {
            current[idx] = dist;
        }
    }

    return time == -1 or SumArrayElements(current) < SumArrayElements(best);
}

void GetRawPoints() {
    string raw_points;
    for (int l = 0; l < num_points; l++) {
        if (GetVariableString("multi_point_" + Text::FormatInt(l)) != "") {
            raw_points += GetVariableString("multi_point_" + Text::FormatInt(l)) + " ";
        }
    }
    SetVariable("multi_point_points", raw_points);
}

bool GetB(string& str) {
    return GetVariableBool(str);
}

void SetEachPoint() {
    auto extracted_points = ExtractRawPoints();
    for (int k = 0; k < num_points; k++) {
        SetVariable("multi_point_" + Text::FormatInt(k), Text::FormatFloat(extracted_points[k][0], "", 0, 3) + " " + Text::FormatFloat(extracted_points[k][1], "", 0, 3) + " " + Text::FormatFloat(extracted_points[k][2], "", 0, 3));
    }
}

array<vec3> ExtractRawPoints() {
    array<string> points = GetVariableString("multi_point_points").Split(" ");
    int raw_length = points.Length - 1;
    array<vec3> extracted_points_local;
    for (int k = 0; k < raw_length / 3; k++){
        extracted_points_local.Add(vec3(Text::ParseFloat(points[k*3]), Text::ParseFloat(points[k*3+1]), Text::ParseFloat(points[k*3+2])));
    }
    return extracted_points_local;
}

float SumArrayElements(array<float> some_array){
    float sum = 0;
    for (int k = 0; k < int(some_array.Length); k++){
        sum += some_array[k];
    }
    return sum;
}

void ReInitBest() {
    best.Clear();
    best.Resize(0);
    for (int i = 0; i < int(final_points.Length); i++) {
        best.Add(float(99999999));
    }
}

void ReInitCurrent() {
    current.Clear();
    current.Resize(0);
    for (int i = 0; i < int(final_points.Length); i++) {
        current.Add(float(99999999));
    }
}

void AddCarPos(int fromTime, int toTime, const string&in commandLine, const array<string>&in args) {
    SetVariable("multi_point_num", ++num_points);
    RegisterVariable("multi_point_" + Text::FormatInt(num_points - 1), "0 0 0");
    SetVariable("multi_point_" + Text::FormatFloat(num_points - 1), carpos.ToString());
}

void Main() {
    RegisterCustomCommand("add_car_pos_point", "Adds car position to multi point bruteforce", AddCarPos);
    RegisterVariable("multi_point_min_eval", 0);
    RegisterVariable("multi_point_max_eval", 10000);
    RegisterVariable("multi_point_points", "0 0 0 1 1 1 2 2 2");
    RegisterVariable("multi_point_num", 2);
    RegisterVariable("multi_point_verbose", false);
    RegisterBruteforceEvaluation("Multi point", "Multi point", OnEvaluate, RenderEvalSettings);
}

void OnRunStep(SimulationManager@ simManager)
{
    carpos = simManager.Dyna.CurrentState.Location.Position;
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    GetVariable("multi_point_num", num_points);
    GetRawPoints();
    final_points = ExtractRawPoints();
    GetVariable("multi_point_min_eval", eval_min);
    GetVariable("multi_point_max_eval", eval_max);
    GetVariable("multi_point_points", raw_points);
    ReInitBest();
    ReInitCurrent();
    time = -1;
}

void OnSimulationStep(SimulationManager@ simManager, bool userCancelled)
{
}

void OnSimulationEnd(SimulationManager@ simManager, SimulationResult result)
{
}

void OnCheckpointCountChanged(SimulationManager@ simManager, int count, int target)
{
}

void OnLapCountChanged(SimulationManager@ simManager, int count, int target)
{
}

void Render()
{
}

void OnDisabled()
{
}

PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "Multi point bf";
    info.Author = "Jsap";
    info.Version = "v1.0.0";
    info.Description = "Multi point bf ig";
    return info;
}
