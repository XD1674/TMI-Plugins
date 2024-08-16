// Documentation available at https://donadigo.com/tminterface/plugins/api

float eval_min;
float eval_max;
float trig_id;
float ratio;
float cap;

array<float> v_base;
array<float> v;

array<float> trigger_prop = {0, 0, 0, 0, 0, 0};

void RenderEvalSettings()
{

    UI::InputIntVar("Trigger index", "tbf_trigger_index", 1);
    Trigger3D trigger = GetTriggerVar();
    if (trigger.Size.x != -1) {
        vec3 pos2 = trigger.Position + trigger.Size;
        UI::TextDimmed("The car must be in the trigger of coordinates: ");
        UI::TextDimmed("" + trigger.Position.ToString() + " " + pos2.ToString());
    }
    UI::SliderFloatVar("Ratio", "tbf_ratio", 0, 100, "%.0f%%");
    UI::Text("Distance                                                      Speed");
    UI::Dummy(vec2(0, 20));
    UI::SliderFloatVar("Min speed", "bf_condition_speed", 0, 1000, "%.2f");
    UI::SliderFloatVar("Speedcap", "tbf_cap", 0, 1000, "%.2f");
    UI::Dummy(vec2(0, 5));
    UI::InputTimeVar("Min time (0 if unsure)", "tbf_min_eval");
    UI::InputTimeVar("Max time", "tbf_max_eval");

}

array<float> best = {-1, -1, -1};
array<float> current = {-1, -1, -1};
int time = -1;
vec3 old_pts;
BFEvaluationResponse@ OnEvaluate(SimulationManager@ simManager, const BFEvaluationInfo&in info)
{
    int raceTime = simManager.RaceTime;
    auto pos = simManager.Dyna.CurrentState.Location.Position;
    
    auto resp = BFEvaluationResponse();
    if (info.Phase == BFPhase::Initial) {
        if (eval_min <= raceTime && raceTime <= eval_max) {
            if (is_better(simManager)) {
                best = current;
                time = raceTime;
            }
            old_pts = pos;
        }
        if (raceTime == eval_max) {
            print("base at " + time + ": distance: " + Text::FormatFloat(best[0], "", 0, 12) + "; speed: " + Text::FormatFloat(best[1] / 3.6, "", 0, 12));
        }
    } else if (info.Phase == BFPhase::Search) {
        if (eval_min <= raceTime && raceTime <= eval_max) {
            if (is_better(simManager)) {
                resp.Decision = BFEvaluationDecision::Accept;
            }
            old_pts = pos;
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
    float speed = Norm(state.LinearSpeed) * 3.6;

    float kmhspeed;
    GetVariable("bf_condition_speed", kmhspeed);

    if (!IsInTrigger(pos)) {
        return false;
    }

    if (speed < kmhspeed) {
        return false;
    }

    if (speed > cap) {
        return false;
    }

    float diff = 999999;
    for (int i = 0; i < 3; i++) {
        float temp = trigger_prop[i + 3] - Math::Abs(trigger_prop[i] - pos[i]);
        if (temp < diff) {
            diff = Math::Abs(temp);
        }
    }

    current[0] = Math::Abs(Distance(old_pts, pos) - diff);
    current[1] = speed;
    current[2] = sim_manager.RaceTime / 10 - diff;

    return time == -1 || (best[2] - current[2]) * (1 - ratio) + (current[1] - best[1]) * (ratio) > 0;
}

bool IsInTrigger(vec3& pos) {
    auto trigger = GetTriggerVar();
    return trigger.ContainsPoint(pos);
}

float Distance(vec3 p1, vec3 p2) {
    return Math::Sqrt( (p1[0] - p2[0])*(p1[0] - p2[0]) + (p1[1] - p2[1])*(p1[1] - p2[1]) + (p1[2] - p2[2])*(p1[2] - p2[2]) );
}

float Norm(vec3& vec) {
    return Math::Sqrt((vec.x * vec.x) + (vec.y * vec.y) + (vec.z * vec.z));
}

float SumArrayElements(array<float> some_array){
    float sum = 0;
    for (int k = 0; k < int(some_array.Length); k++){
        sum += some_array[k];
    }
    return sum;
}

Trigger3D GetTriggerVar() {
    uint triggerIndex = int(GetD("tbf_trigger_index"));
    return GetTriggerByIndex(triggerIndex - 1);
}

double GetD(string& str) {
    return GetVariableDouble(str);
}

void Main() {
    RegisterVariable("tbf_min_eval", 0);
    RegisterVariable("tbf_max_eval", 10000);
    RegisterVariable("tbf_trigger_index", 0);
    RegisterVariable("tbf_ratio", 0);
    RegisterVariable("tbf_cap", 1000);
    RegisterBruteforceEvaluation("Trigger V2", "Trigger V2", OnEvaluate, RenderEvalSettings);
}

void OnRunStep(SimulationManager@ simManager)
{
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    GetVariable("tbf_min_eval", eval_min);
    GetVariable("tbf_max_eval", eval_max);
    GetVariable("tbf_trigger_index", trig_id);
    GetVariable("tbf_ratio", ratio);
    GetVariable("tbf_cap", cap);
    auto trigger = GetTriggerVar();
    trigger_prop = {trigger.Position[0] + trigger.Size[0] / 2,
                    trigger.Position[1] + trigger.Size[1] / 2,
                    trigger.Position[2] + trigger.Size[2] / 2,
                    trigger.Size[0] / 2,
                    trigger.Size[1] / 2,
                    trigger.Size[2] / 2};
    if (eval_max == 0) {
        eval_max = simManager.EventsDuration;
    }
    ratio /= 100;
    best = {-1, -1, -1};
    current = {-1, -1, -1};
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
    info.Name = "Improved trigger bf";
    info.Author = "Jsap";
    info.Version = "v1.0.0";
    info.Description = "Trigger bf with move features";
    return info;
}
