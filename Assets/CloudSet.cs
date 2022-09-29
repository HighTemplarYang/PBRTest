using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode]
public class CloudSet : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        Vector3 bboxMin = transform.position - transform.localScale / 2;
        Color bboxMinColor = new Color(bboxMin.x, bboxMin.y, bboxMin.z);
        Shader.SetGlobalColor("_CloudMin", bboxMinColor);
        Vector3 bboxMax = transform.position + transform.localScale / 2;
        Color bboxMaxColor = new Color(bboxMax.x, bboxMax.y, bboxMax.z);
        Shader.SetGlobalColor("_CloudMax", bboxMaxColor);
    }
}
