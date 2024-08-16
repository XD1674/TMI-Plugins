// Documentation available at https://donadigo.com/tminterface/plugins/api

float eval_min;
float eval_max;
string point_raw;
vec3 any_point;
array<float> p_points = {0,0,0};

void RenderEvalSettings()
{
    GetVariable("any_wheel_point_point", point_raw);

    UI::Dummy(vec2(0, 5));
    UI::InputTimeVar("Eval min", "any_wheel_point_min_eval");
    UI::InputTimeVar("Eval max", "any_wheel_point_max_eval");

    UI::Dummy(vec2(0, 5));
    UI::DragFloat3Var("Point", "any_wheel_point_point");
    GetVariable("any_wheel_point_point", point_raw);
    any_point = PointFromSavedVar(point_raw);
    if (UI::Button("copy point")) {
        auto cam = GetCurrentCamera();
        if (@cam != null) {
            SetVariable("any_wheel_point_point", cam.Location.Position.ToString());
        }
    }
    
    UI::Dummy(vec2(0, 5));
    UI::InputFloatVar("Min speed", "bf_condition_speed", 10);
    UI::InputIntVar("Min CP collected", "any_wheel_min_cp", 1);

}

float best = -1;
float current = -1;
int time = -1;
BFEvaluationResponse@ OnEvaluate(SimulationManager@ simManager, const BFEvaluationInfo&in info)
{
    int raceTime = simManager.RaceTime;

    auto resp = BFEvaluationResponse();
    if (info.Phase == BFPhase::Initial) {
        if (eval_min <= raceTime and raceTime <= eval_max and is_better(simManager)) {
            best = current;
            time = raceTime;
        }
        if (raceTime == eval_max) {
            print("best at " + time + ": " + Text::FormatFloat(best, "", 0, 15));
        }
    } else if (info.Phase == BFPhase::Search) {
        if (eval_min <= raceTime and raceTime <= eval_max and is_better(simManager)) {
            resp.Decision = BFEvaluationDecision::Accept;
            //resp.ResultFileStartContent = "Found better wheel pos " + Time::Format(raceTime) + ": " + Text::FormatFloat(best, "", 0, 15);
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
    auto rot = state.Location.Rotation;
    auto wheels = sim_manager.Wheels;

    float yaw, pitch, roll;
    state.Location.Rotation.GetYawPitchRoll(yaw, pitch, roll);

    float kmhspeed;
    GetVariable("bf_condition_speed", kmhspeed);

    if (Norm(state.LinearSpeed) * 3.6 < kmhspeed) {
        return false;
    }

    int cpCount = int(sim_manager.PlayerInfo.CurCheckpointCount);
    if (cpCount < GetD("any_wheel_min_cp")) {
        return false;
    }

    current = 20000000;

    vec3 wheel_pos;

    for (int i = 0; i < 4; i++) {
        switch(i)
        {
            case 0:
                wheel_pos = mat_mul_vec(rot, wheels.BackRight.OffsetFromVehicle) + pos;
                break;
            
            case 1:
                wheel_pos = mat_mul_vec(rot, wheels.BackLeft.OffsetFromVehicle) + pos;
                break;
            
            case 2:
                wheel_pos = mat_mul_vec(rot, wheels.FrontRight.OffsetFromVehicle) + pos;
                break;
            
            case 3:
                wheel_pos = mat_mul_vec(rot, wheels.FrontLeft.OffsetFromVehicle) + pos;
                break;
        
        }

        float dist = Math::Distance(wheel_pos, any_point); // + (Math::Max(45, 180 - Math::Abs(pitch)) - 45) / 45;

        if (dist < current){
            current = dist;
        }
    }

    return best == -1 or current < best;
}

vec3 mat_mul_vec(const mat3&in m, const vec3&in v) {
    return vec3(Math::Dot(m.x, v), Math::Dot(m.y, v), Math::Dot(m.z, v));
}

vec3 rotate(const quat&in rot_quat, const vec3&in vec_inp) {
    vec3 vec_inp_norm = vec_inp.Normalized();
    quat quat_vec = quat(vec_inp_norm.x, vec_inp_norm.y, vec_inp_norm.z, 0);
    quat quat_conj = quat(-rot_quat.x, -rot_quat.y, -rot_quat.z, rot_quat.w);

    quat quat_multiplied = quat_mul(quat_mul(rot_quat, quat_vec), quat_conj);

    return vec3(quat_multiplied.x, quat_multiplied.y, quat_multiplied.z) * vec_inp.Length();
}

quat quat_mul(const quat&in quat1, const quat&in quat2) {
    return quat(quat1.w * quat2.x + quat1.x * quat2.w + quat1.y * quat2.z - quat1.z * quat2.y,
                quat1.w * quat2.y - quat1.x * quat2.z + quat1.y * quat2.w + quat1.z * quat2.x,
                quat1.w * quat2.z + quat1.x * quat2.y - quat1.y * quat2.x + quat1.z * quat2.w,
                quat1.w * quat2.w - quat1.x * quat2.x - quat1.y * quat2.y - quat1.z * quat2.z);
}

void Main() {
    GetVariable("any_wheel_point_min_eval", eval_min);
    GetVariable("any_wheel_point_max_eval", eval_max);
    GetVariable("any_wheel_point_point", point_raw);
    RegisterVariable("any_wheel_point_min_eval", 0);
    RegisterVariable("any_wheel_point_max_eval", 10000);
    RegisterVariable("any_wheel_point_point", "0 0 0");
    RegisterVariable("any_wheel_min_cp", 0);
    RegisterBruteforceEvaluation("Any wheel point", "Any wheel point", OnEvaluate, RenderEvalSettings);
}

vec3 PointFromSavedVar(string pt)
{
    array<string> splits = pt.Split(" ");
    auto out_vec = vec3(Text::ParseFloat(splits[0]), Text::ParseFloat(splits[1]), Text::ParseFloat(splits[2]));
    return out_vec;
}

float Norm(vec3& vec) {
    return Math::Sqrt((vec.x * vec.x) + (vec.y * vec.y) + (vec.z * vec.z));
}

double GetD(string& str) {
    return GetVariableDouble(str);
}

void OnRunStep(SimulationManager@ simManager)
{
}

void OnSimulationBegin(SimulationManager@ simManager)
{
    GetVariable("any_wheel_point_min_eval", eval_min);
    GetVariable("any_wheel_point_max_eval", eval_max);
    GetVariable("any_wheel_point_point", point_raw);
    best = -1;
    current = -1;
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
    info.Name = "any wheel point";
    info.Author = "Jsap";
    info.Version = "v1.0.0";
    info.Description = "Bruteforce script for point with any wheel";
    return info;
}
